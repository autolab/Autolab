require "tmpdir"

module CourseTransfer
  class Exporter
    def initialize(course, parts: nil, format_version: nil)
      @course = course
      @part_keys = Array(parts).map(&:to_sym).presence
      @format_version = format_version || Version::CURRENT
    end

    # Returns a binary StringIO of the packed course export tarball.
    def call
      Dir.mktmpdir("autolab-course-export-") do |staging_dir|
        context = Context.new(
          course: @course,
          staging_path: Pathname.new(staging_dir),
          version: @format_version,
          mode: :export,
          selected_parts: resolved_part_keys
        )

        Version.write_manifest!(context)

        ordered_parts.each do |part_class|
          part_class.new.export(context)
        end

        Package.pack(context.staging_path)
      end
    end

  private

    def resolved_part_keys
      keys = @part_keys || Registry.default_keys
      Registry.filter_for_version(keys, version: @format_version)
    end

    def ordered_parts
      Registry.ordered(resolved_part_keys)
    end
  end
end
