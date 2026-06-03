# frozen_string_literal: true

require_relative "../export"

module CourseTransfer
  class CourseExporter < Export::InlineDependencyExporter
    def initialize(course)
      super()
      @course = course
    end

    def dependencies(_context: nil)
      { late_slack: Export::InlineValueExporter.new(@course[:late_slack]) }
    end
  end
end
