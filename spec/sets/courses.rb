module Contexts
  module Courses
    def create_course
      @course = FactoryBot.create(:course)

      FactoryBot.create(:course_user_datum, course: @course,
                                            user: @instructor_user,
                                            instructor: true)

      FactoryBot.create(:course_user_datum, course: @course,
                                            user: @course_assistant_user,
                                            instructor: false, course_assistant: true)
    end
  end
end
