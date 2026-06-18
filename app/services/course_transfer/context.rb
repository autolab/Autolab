require "pathname"

module CourseTransfer
  # Immutable runtime information shared by course-transfer services.
  class Context
    attr_reader :staging_path, :version, :course_identifier, :instructor_email

    # @param staging_path [String, Pathname]
    # @param version [String, Gem::Version]
    # @param course_identifier [String, nil] replacement identifier on import
    # @param instructor_email [String, nil] instructor to create or enroll
    def initialize(staging_path:, version:, course_identifier: nil, instructor_email: nil)
      @staging_path = Pathname.new(staging_path)
      @version = version
      @course_identifier = course_identifier&.to_s&.strip
      @instructor_email = instructor_email&.to_s&.strip
    end
  end
end
