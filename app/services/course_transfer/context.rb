# frozen_string_literal: true

module CourseTransfer
  class Context
    attr_reader :staging_path, :course, :version, :mode, :selected_parts

    def initialize(staging_path:, course:, version:, mode:, selected_parts:)
      @staging_path = staging_path
      @course = course
      @version = version
      @mode = mode
      @selected_parts = selected_parts
    end
  end
end
