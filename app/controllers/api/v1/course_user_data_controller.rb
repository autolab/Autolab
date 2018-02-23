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

  def create
    require_params([:email, :lecture, :section, :auth_level])
    set_default_params({dropped: false})

    # check if user exists
    # this method requires that the user with the email already exists,
    # otherwise, the user should be created first in the system
    user = User.find_by(email: params[:email])
    if user.nil?
      raise ApiError.new("Nonexistent user", :bad_request)
    end

    if not user.course_user_data.where(course: @course).empty?
      raise ApiError.new("User already in course", :bad_request)
    end

    cud = @course.course_user_data.new(create_cud_params)
    cud.user = user

    case params[:auth_level]
    when "instructor"
      cud.instructor = true
    when "course_assistant"
      cud.course_assistant = true
    when "student"
    else
      raise ApiError.new("Invalid auth_level", :bad_request)
    end

    if not cud.save
      raise ApiError.new("Creation failed: " + cud.errors.full_messages.join(", "))
    end

    respond_with format_cud_response(cud)
  end

private
  
  def format_cud_response(cud)
    cud_hash = cud.as_json(only: [:lecture, :section, :nickname, :dropped])
    user_hash = cud.user.as_json(only: [:first_name, :last_name, :email, :school, :major, :year])
    cud_hash.merge!(user_hash)
    cud_hash.merge!(:auth_level => cud.auth_level_string)

    return cud_hash
  end

  def create_cud_params
    params.permit(:lecture, :section, :grade_policy, :dropped, :nickname)
  end

end