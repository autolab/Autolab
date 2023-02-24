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
end
