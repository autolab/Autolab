module Contexts
  module Courses
    # TODO: course creation creates a bunch of folders and files that persist
    # should implement some form of cleanup
    def create_course(admin_user: @admin_user,
                      instructor_user: @instructor_user,
                      course_assistant_user: @course_assistant_user,
                      students: @students)
      @course = FactoryBot.create(:course) do |new_course|
        @instructor_cud = create_cud(user: instructor_user, course: new_course, role: 'instructor')
        create_cud(user: admin_user, course: new_course)
        create_cud(user: course_assistant_user, course: new_course, role: 'course_assistant')
        students.each do |student|
          # students in this course are given nicknames to bypass
          # initial cud edit redirect that occurs when no nickname is given
          create_cud(user: student, course: new_course, role: 'student')
        end
      end
    end

    def create_cud(user: @admin_user, course: @course, role: 'admin')
      role = 'admin' if user.administrator # enforce admin if user is admin

      case role
      when 'student'
        FactoryBot.create(:nicknamed_student, course:, user:)
      when 'instructor', 'admin'
        FactoryBot.create(:course_user_datum, course:, user:, instructor: true)
      else
        FactoryBot.create(:course_user_datum, course:, user:,
                                              course_assistant: true)
      end
    end

    def create_course_with_attachment(admin_user: @admin_user,
                                      instructor_user: @instructor_user,
                                      course_assistant_user: @course_assistant_user,
                                      students: @students)
      @course = FactoryBot.create(:course, :with_attachment) do |new_course|
        @instructor_cud = create_cud(user: instructor_user, course: new_course, role: 'instructor')
        create_cud(user: admin_user, course: new_course)
        create_cud(user: course_assistant_user, course: new_course, role: 'course_assistant')
        students.each do |student|
          # students in this course are given nicknames to bypass
          # initial cud edit redirect that occurs when no nickname is given
          create_cud(user: student, course: new_course, role: 'student')
        end
      end
    end
  end
end
