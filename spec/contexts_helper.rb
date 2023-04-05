# require needed files
require 'sets/users'
require 'sets/courses'

module Contexts
  # explicitly include all sets of contexts used for testing
  include Contexts::Users
  include Contexts::Courses

  def create_course_with_users
    create_users
    puts "Built users"
    create_course
    puts "Built courses"
  end

  def create_autograded_course_with_users
    create_users
    puts "Built users"
    create_autograded_course(asmt_name: "autogradecourse")
    puts "Built courses"
  end

  def create_course_with_users_as_hash(asmt_name: "testassessment2")
    if @instructor_user.nil?
      create_users
      puts "Built users"
    end
    create_course(asmt_name: asmt_name)
    puts "Built courses"
    { course: @course, admin_user: @admin_user,
      instructor_user: @instructor_user, course_assistant_user: @course_assistant_user,
      students_cud: @students, assessment: @assessment }
  end
end
