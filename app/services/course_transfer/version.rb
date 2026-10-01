require "pathname"
require "yaml"
require_relative "errors"

module CourseTransfer
  class Version
    CURRENT = 2
    SUPPORTED = [1, CURRENT].freeze
    FORMAT_ID = "autolab_course_export".freeze
    MANIFEST_FILENAME = "manifest.yml".freeze

    class Unsupported < Error; end
    class InvalidManifest < Error; end

    def self.write_manifest!(context, parts: nil)
      path = context.staging_path.join(MANIFEST_FILENAME)
      path.write(
        {
          "format" => FORMAT_ID,
          "version" => CURRENT,
          "created_at" => Time.current.utc.iso8601,
          "parts" => Array(parts).map(&:to_s)
        }.to_yaml
      )
      path
    end

    def self.read_manifest(staging_path)
      path = Pathname.new(staging_path).join(MANIFEST_FILENAME)
      parse_manifest_yaml(path.read) if path.file?
    end

    def self.assert_importable!(version)
      return true if SUPPORTED.include?(version)

      raise Unsupported, "unsupported export format version: #{version.inspect}"
    end

    def self.parse_manifest_yaml(contents)
      data = YAML.safe_load(contents, aliases: false)
      raise InvalidManifest, "manifest.yml must contain a mapping" unless data.is_a?(Hash)
      raise InvalidManifest, "unknown format" unless data["format"] == FORMAT_ID
      raise InvalidManifest, "manifest has an invalid version" unless data["version"].is_a?(Integer)
      unless data["parts"].is_a?(Array) && data["parts"].all? { |part| part.is_a?(String) }
        raise InvalidManifest, "manifest parts must be an array of strings"
      end
      raise InvalidManifest, "manifest parts must be unique" unless data["parts"].uniq == data["parts"]

      data
    rescue Psych::Exception => e
      raise InvalidManifest, "invalid manifest.yml: #{e.message}"
    end
    private_class_method :parse_manifest_yaml
  end
end
