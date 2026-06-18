require "digest"
require "fileutils"
require "pathname"
require_relative "errors"
require_relative "serialization"

module CourseTransfer
  # Reads and writes the portable file manifest and verifies its payloads.
  class FileManifest
    NAME = "files.yml".freeze
    PAYLOAD_DIRECTORY = Pathname.new("files").freeze
    REQUIRED_FIELDS = %w[table key name relative_path payload sha256].freeze

    def initialize(root)
      @root = Pathname.new(root).expand_path
    end

    # @return [void]
    def prepare!
      FileUtils.mkdir_p(@root.join(PAYLOAD_DIRECTORY))
      path.write("")
    end

    # @param index [Integer]
    # @return [Pathname]
    def payload(index)
      @root.join(PAYLOAD_DIRECTORY, format("%08d", index))
    end

    # @return [void]
    def append(table:, key:, name:, relative_path:, payload:)
      document = {
        "table" => table.to_s,
        "key" => key,
        "name" => name,
        "relative_path" => relative_path,
        "payload" => payload.relative_path_from(@root).to_s,
        "sha256" => Digest::SHA256.file(payload).hexdigest
      }
      File.open(path, "a") { |file| Serialization.dump_document(file, document) }
    end

    # @return [Array<Hash>]
    def read
      raise FileTransferError, "#{NAME} is missing" unless path.file?

      File.open(path, "rb") do |input|
        Serialization.each_document(input, filename: NAME).to_a.tap do |documents|
          valid = documents.all? do |document|
            document.is_a?(Hash) && document.keys.sort == REQUIRED_FIELDS.sort
          end
          raise FileTransferError, "#{NAME} contains an invalid file record" unless valid
        end
      end
    rescue Psych::Exception => e
      raise FileTransferError, "#{NAME} is invalid YAML: #{e.message}"
    end

    # @param document [Hash]
    # @return [Pathname]
    def verified_payload(document)
      relative = relative_path(document.fetch("payload"))
      unless within?(relative, PAYLOAD_DIRECTORY)
        raise FileTransferError, "payload escapes package file directory"
      end

      payload = @root.join(relative).expand_path
      unless within?(payload, @root) && payload.file? && !payload.symlink?
        raise FileTransferError, "missing or unsafe file payload"
      end
      unless Digest::SHA256.file(payload).hexdigest == document.fetch("sha256")
        raise FileTransferError, "file payload checksum mismatch"
      end

      payload
    end

    # @param value [Object]
    # @return [Pathname]
    def relative_path(value)
      relative = Pathname.new(value.to_s).cleanpath
      if relative.absolute? || relative.to_s == "." || relative.to_s == ".." ||
         relative.each_filename.first == ".."
        raise FileTransferError, "unsafe package file path"
      end

      relative
    end

  private

    def path
      @root.join(NAME)
    end

    def within?(path, root)
      path = Pathname.new(path).expand_path.to_s
      root = Pathname.new(root).expand_path.to_s
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end
  end
end
