require 'date'

class Api::V1::CoursesController < Api::V1::BaseApiController

  before_action -> {require_privilege :user_courses}, only: [:index]
  before_action -> {require_privilege :admin_all}, only: [:create]

  skip_before_action :set_course
  skip_before_action :authorize_user_for_course

  def index
    courses_for_user = User.courses_for_user current_user

    if params.has_key?(:state)
      if params[:state] == "disabled"
        courses_for_user = courses_for_user.select { |course| course.is_disabled?}
      elsif ["completed", "current", "upcoming"].include? params[:state]
        state = params[:state].to_sym
        courses_for_user = courses_for_user.select { |course| course.temporal_status == state }
      else
        # invalid state
        raise ApiError.new("Unexpected course state", :bad_request)
      end
    end

    # add auth level to the returned object
    uid = current_user.id
    final_course_list = []
    courses_for_user.each do |course|
      course_hash = course.as_json(only: [:name, :display_name, :semester, :late_slack, :grace_days, :auth_level])
      
      cud = CourseUserDatum.find_cud_for_course(course, uid)
      course_hash.merge!(:auth_level => cud.auth_level_string)

      final_course_list << course_hash
    end

    respond_with final_course_list
  end

  # requires admin_all scope and user to be admin
  def create
    require_params([:name, :semester, :instructor_email])
    
    begin
      # name validation done during create
      newCourse = Course.quick_create(params[:name], params[:semester], params[:instructor_email])
    rescue => e
      raise ApiError.new(e.message, :internal_server_error)
    end

    # set additional params
    if params.has_key?(:start_date)
      newCourse.start_date = safe_parse_date(params[:start_date])
    end
    if params.has_key?(:end_date)
      newCourse.end_date = safe_parse_date(params[:end_date])
    end

    # attempt save
    if not newCourse.save
      raise ApiError.new("Failed to create course: #{validation_errors_for(newCourse)}", :bad_request)
    end

    respond_with_hash({name: newCourse.name})
  end

private

  def safe_parse_date(date_str)
    Date.parse(date_str)
  rescue ArgumentError
    raise ApiError.new("Invalid date: #{date_str}", :bad_request)
  end

end