class Api::V1::BaseApiController < ActionController::Base

  # Error type for APIs
  class ApiError < StandardError
    attr_reader :status_code # http error code
    
    def initialize(msg, status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end

  rescue_from ApiError, with: :respond_with_api_error

  respond_to :json

  before_action :doorkeeper_authorize! # OAuth2 token authentication for all actions
  before_action :set_up_logger         # Logger must be setup before everything else
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
    {:json => {:error => "Your client does not have the required scope for this action"}}
  end

  private

  def current_user
    @current_user ||= User.find(doorkeeper_token[:resource_owner_id])
  end

  def current_app
    @current_app ||= Doorkeeper::Application.find(doorkeeper_token[:application_id])
  end

  def respond_with_api_error(error)
    ApiLogger.log(:warn, "#{error.status_code} Error: #{error.message}")
    render :json => {:error => error.message}.to_json, :status => error.status_code
  end

  def respond_with_hash(h)
    render :json => h.to_json
  end

  protected

  # Logger for API controllers
  class ApiLogger
    def self.setup(user_id, client_id, ip)
      @user_id = user_id
      @client_id = client_id
      @ip = ip
    end

    def self.log(level, msg)
      strTime = Time.now.strftime("%m/%d/%y %H:%M:%S")
      Rails.logger.send(level) {"#{level.upcase} -- #{strTime} -- #{@ip} C#{@client_id} U#{@user_id} -- #{msg}"}
    end
  end

  def set_up_logger
    ApiLogger.setup(current_user.id, current_app.id, request.remote_ip)
  end

  def require_params(reqs)
    reqs.each do |item|
      if not params.has_key?(item)
        raise ApiError.new("Required parameter '#{item}' not found", :bad_request)
      end
    end
  end

  def set_default_params(defaults)
    defaults.each_key do |key|
      if not params.has_key?(key)
        params[key] = defaults[key]
      end
    end
  end

  def set_default_response_format
    request.format = :json
  end

  # 2-in-1 checker that checks the client scope and user privileges.
  # Descendants should use this method in before_actions instead of 
  # doorkeeper_authorize!
  #
  # Should only be called by descendants of the BaseApiController
  # to maintain the order of before_actions
  def require_privilege(scope)
    # check if client has the required scope
    doorkeeper_authorize! scope
    return if performed?

    # check if user has heightened privileges
    case scope
    when :admin_all
      if not current_user.administrator?
        raise ApiError.new("User does not have admin privileges", :forbidden)
      end
    when :instructor_all
      # @cud must have been set if the before_action order is correct
      if not @cud.instructor
        raise ApiError.new("User does not have instructor privileges for this course", :forbidden)
      end
    end
  end

  def set_course
    course_name = params[:course_name] ||
                  (params[:controller] == "courses" ? params[:name] : nil)
    @course = Course.find_by(name: course_name) if course_name

    unless @course
      raise ApiError.new("Course does not exist", :not_found)
    end

    COURSE_LOGGER.setCourse(@course)
    ASSESSMENT_LOGGER.setCourse(@course)
  end

  def authorize_user_for_course
    # current user should always exist for API calls through doorkeeper
    uid = current_user.id

    @cud = CourseUserDatum.find_cud_for_course(@course, uid)
    unless @cud
      raise ApiError.new("User is not in this course", :forbidden)
    end

    if @course.is_disabled? && !@cud.has_auth_level?(:instructor)
      raise ApiError.new("Your course has been disabled by your instructor. "\
        "Please contact them directly if you have any questions", :forbidden)
    end
  end

  def set_assessment
    @assessment = @course.assessments.find_by(name: params[:assessment_name] || params[:name])
    unless @assessment
      raise ApiError.new("Assessment does not exist", :not_found)
    end

    if @cud.student? && !@assessment.released?
      # we can let the client know this assessment isn't released yet. No harm in telling them 
      # that this assessment exists.
      raise ApiError.new("Assessment not released yet", :forbidden)
    end

    ASSESSMENT_LOGGER.setAssessment(@assessment)
  end

  # additional helpers
  def validation_errors_for(model)
    model.errors.full_messages.join(", ")
  end

end