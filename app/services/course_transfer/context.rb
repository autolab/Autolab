require "pathname"

module CourseTransfer
  Context = Data.define(:staging_path, :course_identifier, :instructor_email) do
    def initialize(staging_path:, course_identifier: nil, instructor_email: nil)
      super(
        staging_path: Pathname.new(staging_path),
        course_identifier: course_identifier&.to_s&.strip,
        instructor_email: instructor_email&.to_s&.strip
      )
    end
  end
end
