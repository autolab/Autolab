class Api::V1::BaseApiController < ActionController::Base

  # Error type for APIs
  class ApiError < StandardError
    attr_reader :status_code # http error code
    
    def initialize(msg = "Unrecognized request", status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end

  rescue_from ApiError, with: :respond_with_api_error

  respond_to :json

  before_action :doorkeeper_authorize! # OAuth2 token authentication for all actions
  before_action :set_default_response_format

  before_action :set_course, except: [:render_404]
  before_action :authorize_user_for_course, except: [:render_404]

  def render_404
    raise ApiError.new("Invalid request path", :not_found)
  end

  def doorkeeper_unauthorized_render_options(error: nil)
    {:json => {:error => "OAuth2 authorization failed"}}
  end

  def doorkeeper_forbidden_render_options(error: nil)
    {:json => {:error => "You do not have the required scope for this action"}}
  end

  private

  def current_user
    @current_user ||= User.find(doorkeeper_token[:resource_owner_id])
  end

  def current_app
    @current_app ||= Doorkeeper::Application.find(doorkeeper_token[:application_id])
  end

  def respond_with_api_error(error)
    render :json => {:error => error.message}.to_json, :status => error.status_code
  end

  def respond_with_hash(h)
    render :json => h.to_json
  end

  protected

  def set_default_response_format
    request.format = :json
  end

  def set_course
    course_name = params[:course_name] ||
                  (params[:controller] == "courses" ? params[:name] : nil)
    @course = Course.find_by(name: course_name) if course_name

    unless @course
      raise ApiError.new("Course does not exist", :not_found)
    end
  end

  def authorize_user_for_course
    # current user should always exist for API calls through doorkeeper
    uid = current_user.id

    @cud = CourseUserDatum.find_cud_for_course(@course, uid)
  end

  def set_assessment
    begin
      @assessment = @course.assessments.find_by!(name: params[:assessment_name] || params[:name])
    rescue
      raise ApiError.new("Assessment does not exist", :not_found)
    end

    if @cud.student? && !@assessment.released?
      # we can let the client know this assessment isn't released yet. No harm in telling them 
      # that this assessment exists.
      raise ApiError.new("Assessment not released yet", :forbidden)
    end
  end

end