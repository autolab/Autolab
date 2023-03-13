module Contexts
  module Courses
    def create_course(asmt_name: "testassessment5")
      @course = FactoryBot.create(:course) do |new_course|
        if asmt_name =~ /[^a-z0-9]/
          raise ArgumentError("Assessment name must contain only lowercase and digits")
        end

        # create assessment directory
        path = Rails.root.join("courses/#{new_course.name}/#{asmt_name}")
        FileUtils.mkdir_p(path)
        asmt = FactoryBot.create(:assessment, course: new_course, name: asmt_name)
        asmt.construct_default_config_file
        asmt.load_config_file

        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @instructor_user,
                                              instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @admin_user,
                                              instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @course_assistant_user,
                                              instructor: false, course_assistant: true)

        # students in this course are given nicknames to bypass
        # initial cud edit redirect that occurs when no nickname is given
        @students.each do |student|
          FactoryBot.create(:nicknamed_student, course: new_course, user: student)
        end
        @assessment = Assessment.where(course: new_course, name: asmt_name).first
      end
    end
  end
end
