module Contexts
  module Courses
    # TODO: course creation creates a bunch of folders and files that persist
    # should implement some form of cleanup
    def create_course
      @course = FactoryBot.create(:course) do |new_course|
        @instructor_cud = FactoryBot.create(:course_user_datum, course: new_course,
                                                                user: @instructor_user,
                                                                instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @admin_user,
                                              instructor: true)
        FactoryBot.create(:course_user_datum, course: new_course,
                                              user: @course_assistant_user,
                                              instructor: false, course_assistant: true)
        @students.each do |student|
          # students in this course are given nicknames to bypass
          # initial cud edit redirect that occurs when no nickname is given
          FactoryBot.create(:nicknamed_student, course: new_course, user: student)
        end
      end
    end
  end
end
