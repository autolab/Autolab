require "yaml"

module CourseTransfer
  # Defines package format compatibility and manifest operations.
  class Version
    CURRENT = "1.0.0".freeze
    FORMAT_ID = "autolab_course_export".freeze
    MANIFEST_FILENAME = "manifest.yml".freeze
    LEGACY = "legacy".freeze

    # Oldest version this app can import (inclusive bounds as Gem::Version).
    # (should be in the past or current version)
    MIN_SUPPORTED_IMPORT = Gem::Version.new("1.0.0")

    # Oldest version that can import the current version (should be in the past or current version)
    MIN_SUPPORTED_TARGET = Gem::Version.new("1.0.0")

    CURRENT_VERSION = Gem::Version.new(CURRENT)

    class Unsupported < StandardError; end
    class InvalidManifest < StandardError; end

    # Writes the package compatibility manifest.
    #
    # @param context [CourseTransfer::Context]
    # @param parts [Array<String, Symbol>, nil] table files in the package
    # @return [Pathname]
    def self.write_manifest!(context, parts: nil)
      payload = {
        "format" => FORMAT_ID,
        "version" => context.version.to_s,
        "min_target_version" => MIN_SUPPORTED_TARGET.to_s,
        "created_at" => Time.current.utc.iso8601,
        "parts" => Array(parts || context.selected_parts).map(&:to_s)
      }

      path = context.staging_path.join(MANIFEST_FILENAME)
      path.write(payload.to_yaml)
      path
    end

    # Detect format version from an extracted package root directory.
    # Returns LEGACY when no manifest is present (old course tar layout).
    def self.detect(staging_path)
      path = Pathname.new(staging_path).join(MANIFEST_FILENAME)
      return LEGACY unless path.file?

      parse_manifest_yaml(path.read)
    end

    # Detect format version from a packed course tar without full extract.
    # Root-level manifest.yml indicates a new-format export; otherwise legacy.
    def self.detect_from_tar_file(tar_path)
      require "rubygems/package"

      File.open(tar_path, "rb") do |io|
        Gem::Package::TarReader.new(io) do |tar|
          tar.each do |entry|
            next if entry.directory?

            name = entry.full_name.to_s.delete_prefix("./")
            next unless name == MANIFEST_FILENAME

            return parse_manifest_yaml(entry.read)
          end
        end
      end

      LEGACY
    end

    def self.parse_manifest_yaml(contents)
      data = YAML.safe_load(contents, permitted_classes: [Time, Date, DateTime], aliases: false)
      raise InvalidManifest, "manifest.yml is empty" if data.blank?
      raise InvalidManifest, "unknown format" unless data["format"] == FORMAT_ID
      raise InvalidManifest, "missing version" if data["version"].blank?

      data["version"].to_s
    rescue Psych::SyntaxError => e
      raise InvalidManifest, "invalid manifest.yml: #{e.message}"
    end
    private_class_method :parse_manifest_yaml

    # Reads a manifest from an extracted package.
    #
    # @param staging_path [String, Pathname]
    # @return [Hash, nil]
    def self.read_manifest(staging_path)
      path = Pathname.new(staging_path).join(MANIFEST_FILENAME)
      return nil unless path.file?

      YAML.safe_load(path.read, permitted_classes: [Time, Date, DateTime], aliases: false)
    end

    def self.legacy?(version)
      version = version.version if version.respond_to?(:version) && !version.is_a?(String)
      version.to_s == LEGACY
    end

    # Raises Unsupported if this app cannot import the given format version.
    def self.assert_importable!(version:, min_target:)
      return true if legacy?(version)

      begin
        parsed = Gem::Version.new(version.to_s)
        parsed_min_target = Gem::Version.new(min_target.to_s)
      rescue ArgumentError
        raise Unsupported, "invalid export format version: #{version}"
      end

      if parsed < MIN_SUPPORTED_IMPORT
        raise Unsupported,
              "export format #{version} is too old; minimum supported is #{MIN_SUPPORTED_IMPORT}"
      end

      if parsed_min_target > CURRENT_VERSION
        raise Unsupported,
              "export format #{version} is too new for this Autolab " \
              "(the import supports only past #{min_target}); upgrade Autolab to import"
      end

      true
    end

    def self.compatible?(version:, min_target:)
      assert_importable!(version:, min_target:)
      true
    rescue Unsupported
      false
    end
  end
end
