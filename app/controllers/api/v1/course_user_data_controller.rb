class Api::V1::CourseUserDataController < Api::V1::BaseApiController

  before_action -> {require_privilege :instructor_all}
  before_action :set_user, except: [:index, :create]

  def index
    cuds = @course.course_user_data.joins(:user).order("users.email ASC")

    user_list = []
    cuds.each do |cud|
      user_list << format_cud_response(cud)
    end

    respond_with_hash user_list
  end

  def create
    require_params([:email, :lecture, :section, :auth_level])
    set_default_params({dropped: false})

    # call set_user manually here since we need to first make sure the email
    # param exists for this create request
    set_user

    if not @user.course_user_data.where(course: @course).empty?
      raise ApiError.new("User is already in the course", :bad_request)
    end

    cud = @course.course_user_data.new(create_cud_params)
    cud.user = @user

    update_cud_auth_level(cud, params[:auth_level])

    if not cud.save
      raise ApiError.new("Creation failed: " + validation_errors_for(cud), :bad_request)
    end

    respond_with_hash format_cud_response(cud)
  end

  def show
    cud = get_user_cud

    respond_with_hash format_cud_response(cud)
  end

  def update
    cud = get_user_cud

    update_cud_auth_level(cud, params[:auth_level])

    # the first save call is for saving the auth_level update
    # the second update call updates and saves the other params
    if not (cud.save && cud.update(update_cud_params))
      raise ApiError.new("Update failed: " + validation_errors_for(cud), :bad_request)
    end

    respond_with_hash format_cud_response(cud)
  end

  # completely deleting a user from a course is not supported over api.
  # the destroy route is a shortcut for dropping a student via an update
  def destroy
    cud = get_user_cud

    if not cud.update(dropped: true)
      raise ApiError.new("Update failed: " + validation_errors_for(cud), :bad_request)
    end

    respond_with_hash format_cud_response(cud)
  end

private

  def set_user
    # check if user exists
    # this method requires that the user with the email already exists,
    # otherwise, the user should be created first in the system
    @user = User.find_by(email: params[:email])
    if @user.nil?
      raise ApiError.new("Nonexistent user", :bad_request)
    end
  end

  def get_user_cud
    cud = @user.course_user_data.find_by(course: @course)
    if cud.nil?
      raise ApiError.new("User is not in course", :not_found)
    end
    return cud
  end
  
  def format_cud_response(cud)
    cud_hash = cud.as_json(only: [:lecture, :section, :grade_policy, :nickname, :dropped])
    user_hash = cud.user.as_json(only: [:first_name, :last_name, :email, :school, :major, :year])
    cud_hash.merge!(user_hash)
    cud_hash.merge!(:auth_level => cud.auth_level_string)

    return cud_hash
  end

  def create_cud_params
    params.permit(:lecture, :section, :grade_policy, :dropped, :nickname)
  end

  def update_cud_params
    params.permit(:lecture, :section, :grade_policy, :dropped, :nickname)
  end

  def update_cud_auth_level(cud, auth_level)
    return unless auth_level

    case auth_level
    when "instructor"
      cud.instructor = true
      cud.course_assistant = false
    when "course_assistant"
      cud.instructor = false
      cud.course_assistant = true
    when "student"
      cud.instructor = false
      cud.course_assistant = false
    else
      raise ApiError.new("Invalid auth_level", :bad_request)
    end
  end

end