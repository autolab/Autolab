# frozen_string_literal: true

module CourseTransfer
  class Context
    attr_reader :staging_path, :course, :version, :selected_parts

    # @param staging_path [String]
    # @param course [Course]
    # @param version [Version]
    # @param selected_parts [Array<String>]
    def initialize(staging_path:, course:, version:, mode:, selected_parts:)
      @staging_path = staging_path
      @course = course
      @version = version
      @selected_parts = selected_parts
    end
  end
end
