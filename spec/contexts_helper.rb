# require needed files
require 'sets/users'
require 'sets/courses'
require 'sets/assessments'
require 'sets/problems'
require 'sets/submissions'

module Contexts
  # explicitly include all sets of contexts used for testing
  include Contexts::Users
  include Contexts::Courses
  include Contexts::Assessments
  include Contexts::Problems
  include Contexts::Submissions

  def create_course_with_users(asmt_name: "testassessment")
    if @instructor_user.nil?
      create_users
      puts "Built users"
    end
    create_course
    puts "Built courses"
    create_assessment(asmt_name:)
    puts "Built assessments"
    create_problems
    puts "Built problems"
    create_submissions_for_assignment
    puts "Built submissions"
  end

  def create_course_no_submissions_hash(asmt_name: "testasmtnosubs")
    if @instructor_user.nil?
      create_users
      puts "Built users"
    end
    create_course
    puts "Built courses"
    create_assessment(asmt_name:)
    puts "Built assessments"
    create_problems
    puts "Built problems"
    { course: @course, admin_user: @admin_user,
      instructor_user: @instructor_user, course_assistant_user: @course_assistant_user,
      students_cud: @students, assessment: @assessment }
  end

  def create_autograded_course_with_users
    create_users
    puts "Built users"
    create_course
    puts "Built courses"
    create_assessment(asmt_name: "autograded")
    puts "Built assessments"
    create_problems
    puts "Built problems"
    create_autograded_problem
    puts "Built autograded problem"
    create_submissions_for_assignment
    puts "Built submissions"
  end

  def create_course_with_users_as_hash(asmt_name: "testassessment2")
    create_course_with_users(asmt_name:)
    { course: @course, admin_user: @admin_user,
      instructor_user: @instructor_user, course_assistant_user: @course_assistant_user,
      students_cud: @students, assessment: @assessment }
  end

  def create_course_with_attachment_as_hash
    create_users
    puts "Built users"
    create_course_with_attachment
    puts "Built course"
    { course: @course, admin_user: @admin_user,
      instructor_user: @instructor_user, course_assistant_user: @course_assistant_user,
      students_cud: @students, assessment: @assessment, attachment: @attachment }
  end
end
