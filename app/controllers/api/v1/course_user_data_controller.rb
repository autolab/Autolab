class Api::V1::CourseUserDataController < Api::V1::BaseApiController

  before_action -> {require_privilege :instructor_all}

  def index
    cuds = @course.course_user_data.joins(:user).order("users.email ASC")

    user_list = []
    cuds.each do |cud|
      user_list << format_cud_response(cud)
    end

    respond_with user_list
  end

private
  
  def format_cud_response(cud)
    cud_hash = cud.as_json(only: [:lecture, :section, :nickname, :dropped])
    user_hash = cud.user.as_json(only: [:first_name, :last_name, :email, :school, :major, :year])
    cud_hash.merge!(user_hash)

    if cud.instructor?
      cud_hash.merge!(:auth_level => "instructor")
    elsif cud.course_assistant?
      cud_hash.merge!(:auth_level => "course_assistant")
    else
      cud_hash.merge!(:auth_level => "student")
    end

    return cud_hash
  end

end