# frozen_string_literal: true

module CourseTransfer
  class BundleExporter < Export::FileYamlExporter
    def initialize(course)
      super(filename: "bundle.yaml")
      @course = course
    end

    def dependencies(_context: nil)
      { course: CourseExporter.new(@course) }
    end
  end
end
