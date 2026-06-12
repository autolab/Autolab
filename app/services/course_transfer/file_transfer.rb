require "fileutils"
require "find"
require "pathname"
require "tempfile"
require_relative "file_manifest"
require_relative "file_mapping"

module CourseTransfer
  # Copies exporter-declared files into and out of a transfer package.
  class FileTransfer
    # @param plan [CourseTransfer::ExportPlan]
    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param key_maps [Hash]
    # @return [void]
    def self.export(plan, registry, context:, key_maps:)
      new(context:, key_maps:).export(plan, registry)
    end

    # @param registry [CourseTransfer::ExportRegistry]
    # @param context [CourseTransfer::Context]
    # @param imported_ids [Hash{Symbol => Array<Integer>}]
    # @param key_maps [Hash]
    # @return [CourseTransfer::FileTransfer] cleanup handle
    def self.import(registry, context:, imported_ids:, key_maps:)
      transfer = new(context:, key_maps:)
      transfer.import(registry, imported_ids)
      transfer
    rescue StandardError
      transfer&.cleanup!
      raise
    end

    def initialize(context:, key_maps:)
      @manifest = FileManifest.new(context.staging_path)
      @key_maps = key_maps
      @written_files = []
      @uploaded_blobs = []
    end

    # @param plan [CourseTransfer::ExportPlan]
    # @param registry [CourseTransfer::ExportRegistry]
    # @return [void]
    def export(plan, registry)
      @sequence = 0
      @manifest.prepare!

      plan.each do |table, relation|
        registry.fetch(table).file_mappings(relation).each do |mapping|
          each_source(mapping) do |source, relative_path|
            export_file(table, mapping, source, relative_path)
          end
        end
      end
    end

    # @param registry [CourseTransfer::ExportRegistry]
    # @param imported_ids [Hash{Symbol => Array<Integer>}]
    # @return [void]
    def import(registry, imported_ids)
      documents = @manifest.read
      unknown_tables = documents.map { |document| document.fetch("table") }.uniq -
                       registry.names.map(&:to_s)
      unless unknown_tables.empty?
        raise FileTransferError, "files reference unknown table #{unknown_tables.first.inspect}"
      end

      registry.each do |exporter|
        ids = imported_ids.fetch(exporter.name, []).uniq
        next if ids.empty?

        mappings = exporter.file_mappings(exporter.model_class.where(id: ids)).index_by do |mapping|
          [mapping.record.id, mapping.name]
        end

        documents.select { |document| document.fetch("table") == exporter.name.to_s }
                 .each { |document| import_file(exporter.name, mappings, document) }
      end
    end

    # Removes external files written by a database transaction that rolled
    # back. Database rows themselves are removed by the transaction.
    #
    # @return [void]
    def cleanup!
      cleanup_each(@uploaded_blobs) { |blob| blob.service.delete(blob.key) }
      cleanup_each(@written_files.reverse_each) { |path| FileUtils.rm_f(path) }
    end

  private

    def each_source(mapping, &block)
      validate_path_mapping(mapping) unless mapping.type == :active_storage

      case mapping.type
      when :tree
        each_tree_file(mapping, &block)
      when :file
        yield_path(mapping.path, nil, &block)
      when :active_storage
        if mapping.attachment.attached?
          yield mapping.attachment.blob, nil
        else
          validate_source_path(mapping.path, mapping.root)
          yield_path(mapping.path, nil, &block)
        end
      else
        raise FileTransferError, "unknown file mapping type #{mapping.type.inspect}"
      end
    end

    def each_tree_file(mapping)
      root = pathname(mapping.path)
      return unless root.directory?
      raise FileTransferError, "symbolic links are not exportable: #{root}" if root.symlink?

      excluded = mapping.exclude.map { |path| pathname(path) }
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

        yield path, path.relative_path_from(root).to_s
      end
    end

    def yield_path(value, relative_path)
      return if value.blank?

      path = pathname(value)
      return unless path.exist?
      raise FileTransferError, "symbolic links are not exportable: #{path}" if path.symlink?
      raise FileTransferError, "special files are not exportable: #{path}" unless path.file?

      yield path, relative_path
    end

    def export_file(table, mapping, source, relative_path)
      payload = @manifest.payload(@sequence)
      @sequence += 1

      open_source(source) do |input|
        File.open(payload, "wb") { |output| IO.copy_stream(input, output) }
      end

      @manifest.append(
        table:,
        key: @key_maps.fetch(table).fetch(mapping.record.id),
        name: mapping.name,
        relative_path:,
        payload:
      )
    rescue KeyError => e
      raise FileTransferError, "missing portable file owner key: #{e.message}"
    rescue SystemCallError => e
      raise FileTransferError, "unable to export file: #{e.message}"
    end

    def import_file(table, mappings, document)
      owner_id = @key_maps.fetch(table).fetch(FileManifest.canonical(document.fetch("key"))) do
        raise FileTransferError, "file references missing #{table} owner"
      end
      mapping = mappings.fetch([owner_id, document.fetch("name")]) do
        raise FileTransferError, "no import mapping for #{table} file"
      end
      payload = @manifest.verified_payload(document)

      if mapping.type == :active_storage
        import_attachment(mapping, payload)
      else
        import_path(mapping, document, payload)
      end
    end

    def import_attachment(mapping, payload)
      File.open(payload, "rb") do |input|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: input,
          filename: mapping.record.filename,
          content_type: mapping.record.mime_type
        )
        @uploaded_blobs << blob
        mapping.attachment.attach(blob)
      end
    end

    def import_path(mapping, document, payload)
      validate_path_mapping(mapping)
      root = pathname(mapping.root)
      destination = if mapping.type == :tree
                      root.join(@manifest.relative_path(document.fetch("relative_path")))
                    else
                      pathname(mapping.path)
                    end
      unless within?(destination, root) && destination != root
        raise FileTransferError, "file destination escapes owner directory"
      end

      reject_symlink_ancestors(destination, pathname(mapping.base))
      if destination.exist?
        raise FileTransferError,
              "destination file already exists: #{destination}"
      end

      FileUtils.mkdir_p(destination.dirname)
      Tempfile.create("course-transfer", destination.dirname) do |temporary|
        temporary.binmode
        File.open(payload, "rb") { |input| IO.copy_stream(input, temporary) }
        temporary.flush
        File.link(temporary.path, destination)
      end
      @written_files << destination
    rescue SystemCallError => e
      raise FileTransferError, "unable to restore file: #{e.message}"
    end

    def open_source(source, &block)
      source.is_a?(Pathname) ? File.open(source, "rb", &block) : source.open(&block)
    end

    def reject_symlink_ancestors(path, base)
      path.ascend do |ancestor|
        break unless within?(ancestor, base)

        if ancestor.symlink?
          raise FileTransferError, "file destination contains a symbolic link"
        end
        break if ancestor == base
      end
    end

    def validate_path_mapping(mapping)
      base = pathname(mapping.base)
      root = pathname(mapping.root)
      unless within?(root, base) && root != base
        raise FileTransferError, "file root escapes its course directory"
      end

      return unless mapping.type == :file

      validate_source_path(mapping.path, root)
    end

    def validate_source_path(value, root)
      return if value.blank?

      path = pathname(value)
      return if within?(path, pathname(root)) && path != pathname(root)

      raise FileTransferError, "file path escapes its owner directory"
    end

    def cleanup_each(items)
      items.each do |item|
        yield item
      rescue StandardError => e
        Rails.logger.error("Course transfer file cleanup failed: #{e.class}: #{e.message}")
      end
    end

    def pathname(value)
      Pathname.new(value).expand_path
    end

    def within?(path, root)
      path = pathname(path).to_s
      root = pathname(root).to_s
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end
  end
end
