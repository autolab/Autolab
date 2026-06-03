# frozen_string_literal: true

require_relative "course_exporter"
require_relative "../version"

module CourseTransfer
  class BundleExporter < Export::FileYamlExporter
    def initialize(course)
      super(filename: "bundle.yaml")
      @course = course
    end

    def dependencies(_context: nil)
      { course: CourseExporter.new(@course) }
    end

    def post_export_hook(dependency_values, _context: nil)
      result = super(dependency_values, _context: _context)
      Version.write_manifest!(_context)
      result
    end
  end
end
