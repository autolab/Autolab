require "digest"
require "fileutils"
require "find"
require "json"
require "pathname"
require "yaml"

module CourseTransfer
  # Raised when a mapped file cannot be copied or restored safely.
  class FileTransferError < StandardError; end

  # Describes one file owned by an exported database record.
  FileMapping = Struct.new(
    :record, :kind, :source, :destination, :relative_path, :destination_type,
    :destination_root, keyword_init: true
  )

  # Runs exporter-declared file mappings for both package directions.
  class FileTransfer
    MANIFEST_FILENAME = "files.yml".freeze
    PAYLOAD_ROOT = Pathname.new("files/payloads").freeze

    # @param plan [CourseTransfer::ExportPlan]
    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param key_maps [Hash]
    # @return [void]
    def self.export(plan, registry, context:, key_maps:)
      writer = ExportWriter.new(context:, key_maps:)
      plan.each do |name, relation|
        registry.fetch(name).file_mappings(relation, direction: :export).each do |mapping|
          writer.write(name, mapping)
        end
      end
    end

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param imported_ids [Hash{Symbol => Array<Integer>}]
    # @param key_maps [Hash]
    # @return [CourseTransfer::FileTransfer::ImportCleanup]
    def self.import(registry, context:, imported_ids:, key_maps:)
      reader = ImportReader.new(context:, key_maps:)
      registry.each do |exporter|
        ids = imported_ids.fetch(exporter.name, []).uniq
        next if ids.empty?

        relation = exporter.model_class.where(id: ids)
        mappings = exporter.file_mappings(relation, direction: :import)
        reader.restore(exporter.name, mappings)
      end
      reader
    rescue StandardError
      reader&.cleanup!
      raise
    end

    # Builds mappings for every regular file in a directory tree.
    #
    # During import, +relative_path+ is supplied by the package manifest, so
    # the mapping only needs to provide the destination root.
    #
    # @param record [ApplicationRecord]
    # @param root [String, Pathname]
    # @param exclude [Array<String, Pathname>]
    # @param direction [:export, :import]
    # @param kind [String]
    # @return [Array<CourseTransfer::FileMapping>]
    def self.tree_mappings(record, root:, direction:, exclude: [], kind: "tree")
      root = Pathname.new(root).expand_path
      return [] unless root.directory? || direction == :import

      if direction == :import
        return [
          FileMapping.new(
            record:,
            kind:,
            destination: root,
            destination_type: :directory
          )
        ]
      end

      excluded = exclude.map { |path| Pathname.new(path).expand_path }
      mappings = []
      Find.find(root.to_s) do |entry|
        path = Pathname.new(entry)
        next if path == root

        if excluded.any? { |excluded_path| within?(path, excluded_path) }
          Find.prune if path.directory?
          next
        end

        raise FileTransferError, "symbolic links are not exportable: #{path}" if path.symlink?
        next if path.directory?
        raise FileTransferError, "special files are not exportable: #{path}" unless path.file?

        mappings << FileMapping.new(
          record:,
          kind:,
          source: path,
          relative_path: path.relative_path_from(root).to_s
        )
      end
      mappings
    rescue Errno::EACCES, Errno::EPERM => e
      raise FileTransferError, "unable to read #{root}: #{e.message}"
    end

    # Source wrapper for an Active Storage blob.
    class BlobSource
      # @param attachment [Attachment]
      def initialize(attachment)
        @attachment = attachment
      end

      # @yieldparam file [File]
      # @return [Object]
      def open(&block)
        @attachment.attachment_file.blob.open(&block)
      end
    end

    # Removes files written before a failed database transaction commits.
    class ImportCleanup
      def initialize
        @files = []
        @blobs = []
      end

      # @param path [String, Pathname]
      # @return [void]
      def track_file(path)
        @files << Pathname.new(path)
      end

      # @param blob [ActiveStorage::Blob]
      # @return [void]
      def track_blob(blob)
        @blobs << blob
      end

      # @return [void]
      def cleanup!
        @blobs.each { |blob| blob.service.delete(blob.key) }
        @files.each do |path|
          FileUtils.rm_f(path)
          parent = path.dirname
          while parent.directory? && parent != Rails.root
            begin
              Dir.rmdir(parent)
            rescue SystemCallError
              break
            end
            parent = parent.dirname
          end
        end
      rescue StandardError => e
        Rails.logger.error("Course transfer file cleanup failed: #{e.class}: #{e.message}")
      end
    end

    def self.within?(path, root)
      path_string = Pathname.new(path).expand_path.to_s
      root_string = Pathname.new(root).expand_path.to_s
      path_string == root_string || path_string.start_with?("#{root_string}#{File::SEPARATOR}")
    end

    class ExportWriter
      def initialize(context:, key_maps:)
        @context = context
        @key_maps = key_maps
        @manifest = context.staging_path.join(MANIFEST_FILENAME)
        FileUtils.mkdir_p(context.staging_path.join(PAYLOAD_ROOT))
        @manifest.write("")
      end

      def write(owner_table, mapping)
        return if mapping.source.nil?

        owner_key = @key_maps.fetch(owner_table).fetch(mapping.record.id)
        descriptor = {
          "owner_table" => owner_table.to_s,
          "owner_key" => owner_key,
          "kind" => mapping.kind.to_s,
          "relative_path" => mapping.relative_path
        }
        digest = Digest::SHA256.hexdigest(JSON.generate(normalize(descriptor)))
        payload_relative = PAYLOAD_ROOT.join(digest)
        payload = @context.staging_path.join(payload_relative)
        copy_source(mapping.source, payload)

        document = descriptor.merge(
          "payload_path" => payload_relative.to_s,
          "byte_size" => payload.size,
          "sha256" => Digest::SHA256.file(payload).hexdigest,
          "mode" => source_mode(mapping.source)
        )
        File.open(@manifest, "a") { |file| file.write(YAML.dump(normalize(document))) }
      rescue KeyError => e
        raise FileTransferError, "missing portable file owner key: #{e.message}"
      rescue SystemCallError => e
        raise FileTransferError, "unable to export #{mapping.source}: #{e.message}"
      end

    private

      def copy_source(source, destination)
        FileUtils.mkdir_p(destination.dirname)
        source_open(source) do |input|
          File.open(destination, "wb") { |output| IO.copy_stream(input, output) }
        end
      end

      def source_open(source, &block)
        if source.respond_to?(:open)
          source.open(&block)
        else
          File.open(source, "rb", &block)
        end
      end

      def source_mode(source)
        return File.stat(source).mode & 0o777 unless source.is_a?(BlobSource)

        0o644
      end

      def normalize(value)
        case value
        when Time, DateTime
          value.iso8601(6)
        when Date
          value.iso8601
        when Hash
          value.sort.to_h.transform_values { |nested| normalize(nested) }
        when Array
          value.map { |nested| normalize(nested) }
        else
          value
        end
      end
    end

    class ImportReader
      def initialize(context:, key_maps:)
        @context = context
        @key_maps = key_maps
        @cleanup = ImportCleanup.new
        @documents = read_manifest
      end

      def restore(owner_table, mappings)
        mapping_index = mappings.index_by do |mapping|
          [mapping.record.id, mapping.kind.to_s, mapping.relative_path]
        end
        mappings_by_owner_and_kind = mappings.group_by { |mapping|
          [mapping.record.id, mapping.kind.to_s]
        }

        documents_for(owner_table).each do |document|
          owner_id = resolve_owner_id(owner_table, document.fetch("owner_key"))
          kind = document.fetch("kind")
          relative_path = document.fetch("relative_path")
          mapping = mapping_index[[owner_id, kind, relative_path]]
          mapping ||= mappings_by_owner_and_kind[[owner_id, kind]]&.find do |candidate|
            candidate.relative_path.nil?
          end
          raise FileTransferError, "no import mapping for #{owner_table} file" unless mapping

          payload = verified_payload(document)
          restore_mapping(mapping, document, payload)
        end
      end

      # @return [void]
      def cleanup!
        @cleanup.cleanup!
      end

    private

      def read_manifest
        path = @context.staging_path.join(MANIFEST_FILENAME)
        return [] unless path.file?

        stream = Psych.parse_stream(path.read, filename: MANIFEST_FILENAME)
        stream.children.map do |document|
          class_loader = Psych::ClassLoader::Restricted.new([], [])
          scanner = Psych::ScalarScanner.new(class_loader)
          visitor = Psych::Visitors::NoAliasRuby.new(
            scanner,
            class_loader,
            symbolize_names: false,
            freeze: false
          )
          value = visitor.accept(document)
          validate_document(value)
          value
        end
      rescue Psych::Exception => e
        raise FileTransferError, "#{MANIFEST_FILENAME} is invalid YAML: #{e.message}"
      end

      def validate_document(document)
        required = %w[owner_table owner_key kind relative_path payload_path byte_size sha256 mode]
        unless document.is_a?(Hash) && (required - document.keys).empty?
          raise FileTransferError, "#{MANIFEST_FILENAME} contains an invalid file record"
        end

        relative = safe_relative(document.fetch("payload_path"))
        return if FileTransfer.within?(relative, PAYLOAD_ROOT)

        raise FileTransferError, "payload escapes package payload directory"
      end

      def documents_for(owner_table)
        @documents.select { |document| document.fetch("owner_table") == owner_table.to_s }
      end

      def resolve_owner_id(owner_table, owner_key)
        @key_maps.fetch(owner_table).fetch(canonical_key(owner_key)) do
          raise FileTransferError, "file references missing #{owner_table} owner"
        end
      end

      def verified_payload(document)
        relative = safe_relative(document.fetch("payload_path"))
        payload = @context.staging_path.join(relative).expand_path
        unless FileTransfer.within?(payload, @context.staging_path) &&
               payload.file? && !payload.symlink?
          raise FileTransferError, "missing or unsafe file payload"
        end
        unless payload.size == Integer(document.fetch("byte_size")) &&
               Digest::SHA256.file(payload).hexdigest == document.fetch("sha256")
          raise FileTransferError, "file payload checksum mismatch"
        end

        payload
      end

      def restore_mapping(mapping, document, payload)
        if mapping.destination_type == :active_storage
          File.open(payload, "rb") do |input|
            blob = ActiveStorage::Blob.create_and_upload!(
              io: input,
              filename: mapping.record.filename,
              content_type: mapping.record.mime_type
            )
            @cleanup.track_blob(blob)
            mapping.record.attachment_file.attach(blob)
          end
          mapping.record.save!
          return
        end

        if mapping.destination_type == :directory
          root = Pathname.new(mapping.destination).expand_path
          destination = root.join(safe_relative(document.fetch("relative_path")))
          unless FileTransfer.within?(destination, root) && destination != root
            raise FileTransferError, "file destination escapes owner directory"
          end
        else
          destination = Pathname.new(mapping.destination).expand_path
          if mapping.destination_root
            root = Pathname.new(mapping.destination_root).expand_path
            unless FileTransfer.within?(destination, root) && destination != root
              raise FileTransferError, "file destination escapes owner directory"
            end
          end
        end
        if destination.exist?
          raise FileTransferError,
                "destination file already exists: #{destination}"
        end

        FileUtils.mkdir_p(destination.dirname)
        File.open(payload, "rb") do |input|
          File.open(destination, "wb") { |output| IO.copy_stream(input, output) }
        end
        File.chmod(Integer(document.fetch("mode")) & 0o777, destination)
        @cleanup.track_file(destination)
      rescue ActiveRecord::ActiveRecordError => e
        raise FileTransferError, "unable to attach file: #{e.message}"
      rescue SystemCallError => e
        raise FileTransferError, "unable to restore file: #{e.message}"
      end

      def safe_relative(value)
        path = Pathname.new(value.to_s).cleanpath
        if path.absolute? || path.to_s == "." || path.to_s == ".." ||
           path.each_filename.first == ".."
          raise FileTransferError, "unsafe package file path"
        end

        path
      end

      def canonical_key(value)
        JSON.generate(normalize(value))
      end

      def normalize(value)
        case value
        when Time, DateTime
          value.iso8601(6)
        when Date
          value.iso8601
        when Hash
          value.sort.to_h.transform_values { |nested| normalize(nested) }
        when Array
          value.map { |nested| normalize(nested) }
        else
          value
        end
      end
    end
  end
end
