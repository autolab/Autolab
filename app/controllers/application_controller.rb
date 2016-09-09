##
# All Controllers inherit this controller.  It handles setting @course, and doing authentication
# and authorization.  It also has functions for loading assessments and submissions so that
# various validations are always applied, so use those functions as before_actions!
#
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
#
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  before_action :configure_permitted_paramters, if: :devise_controller?
  before_action :maintenance_mode?
  before_action :run_scheduler

  before_action :authenticate_user!
  before_action :set_course
  before_action :authorize_user_for_course, except: [:action_no_auth]
  before_action :authenticate_for_action
  before_action :update_persistent_announcements
  before_action :set_breadcrumbs

  # this is where Error Handling is configured. this routes exceptions to
  # the error handler in the HomeController, unless we're in development mode
  #
  # the policy is basically a replica of Rails's default error handling policy
  # described in http://guides.rubyonrails.org/action_controller_overview.html#rescue
  unless Rails.env.development?
    # going against all logic, handlers registered last get called first
    rescue_from Exception, with: :render_error
    rescue_from CourseUserDatum::AuthenticationFailed do |e|
      COURSE_LOGGER.log("AUTHENTICATION FAILED: #{e.user_message}, #{e.dev_message}")
      respond_to do |format| 
         format.html {
            flash[:error] = e.user_message
            redirect_to root_path
         }
         format.json { head :forbidden }
         format.js { head :forbidden }
      end
    end
  end

  def self.autolab_require(path)
    $LOADED_FEATURES.delete(path) if (Rails.env == "development")
    require(path)
  end

  @@global_whitelist = {}
  def self.action_auth_level(action, level)
    fail ArgumentError, "The action must be specified." if action.nil?
    fail ArgumentError, "The action must be symbol." unless action.is_a? Symbol
    fail ArgumentError, "The level must be specified." if level.nil?
    fail ArgumentError, "The level must be symbol." unless level.is_a? Symbol
    unless CourseUserDatum::AUTH_LEVELS.include?(level)
      fail ArgumentError, "#{level} is not an auth level"
    end

    if level == :administrator
      skip_before_action :set_course, only: [action]
      skip_before_action :authorize_user_for_course, only: [action]
      skip_filter authenticate_for_action: [action]
      skip_before_action :update_persistent_announcements, only: [action]
    end

    controller_whitelist = (@@global_whitelist[controller_name.to_sym] ||= {})
    fail ArgumentError, "#{action} already specified." if controller_whitelist[action]

    controller_whitelist[action] = level
  end

  def self.action_no_auth(action)
    skip_before_action :verify_authenticity_token, :authenticate_user!
    skip_filter configure_permitted_paramters: [action]
    skip_filter maintenance_mode: [action]
    skip_filter run_scheduler: [action]

    skip_filter authenticate_user: [action]
    skip_before_action :authorize_user_for_course, only: [action]
    skip_filter authenticate_for_action: [action]
    skip_before_action :update_persistent_announcements, only: [action]
  end

protected

  def configure_permitted_paramters
    devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:email) }
    devise_parameter_sanitizer.for(:sign_up) do |u|
      u.permit(:email, :first_name, :last_name, :password, :password_confirmation)
    end
    devise_parameter_sanitizer.for(:account_update) do |u|
      u.permit(:email, :password, :password_confirmation, :current_password)
    end
  end

  def authentication_failed(user_message = nil, dev_message = nil)
    user_message ||= "You are not authorized to view this page"

    if user_signed_in?
      dev_message ||= "For user #{current_user.email}"
    else
      dev_message ||= "Before initial user authentication."
    end

    fail CourseUserDatum::AuthenticationFailed.new(user_message, dev_message)
  end

  def authenticate_for_action
    controller_whitelist = @@global_whitelist[params[:controller].to_sym]
    return if controller_whitelist.nil?

    level = controller_whitelist[params[:action].to_sym]
    return if level.nil?

    if level == :administrator
      authentication_failed unless current_user.administrator
    else
      authentication_failed unless @cud.has_auth_level?(level)
    end
  end

  protect_from_forgery
  def verify_authenticity_token
    msg = "Invalid request! Please go back, reload the " \
        "page and try again.  If you continue to see this error. " \
        " please contact the Autolab Development team at the " \
        "contact link below"

    authentication_failed(msg) unless verified_request?
  end

  def maintenance_mode?
    # enable/disable maintenance mode with this switch:
    return unless ENV["AUTOLAB_MAINTENANCE"]
    render(:maintenance) && return unless user_signed_in? && current_user.administrator?
  end

  def set_course
    course_name = params[:course_name] ||
                  (params[:controller] == "courses" ? params[:name] : nil)
    @course = Course.find_by(name: course_name) if course_name

    unless @course
      flash[:error] = "Course #{params[:course_name]} does not exist!"
      redirect_to(controller: :home, action: :error) && return
    end

    # set course logger
    begin
      COURSE_LOGGER.setCourse(@course)
    rescue StandardError => e
      flash[:error] = e.to_s
      redirect_to(controller: :home, action: :error) && return
    end
  end

  def authorize_user_for_course
    redirect_to(root_path) && return if current_user.nil?

    uid = current_user.id
    # don't allow sudoing across courses
    if session[:sudo]
      if (@course.id == session[:sudo]["course_id"])
        uid = session[:sudo]["user_id"]
      else
        session[:sudo] = nil
      end
    end

    # set @cud
    cud, reason = CourseUserDatum.find_or_create_cud_for_course @course, uid
    case reason
    when :found
      @cud = cud

    when :admin_created
      @cud = cud
      flash[:info] = "Administrator user added to course"

    when :admin_creation_error
      flash[:error] = "Error adding user: #{current_user.email} to course"
      redirect_to(controller: :home, action: :error) && return

    when :unauthorized
      flash[:error] = "User #{current_user.email} is not in this course"
      redirect_to(controller: :home, action: :error) && return
    end

    # check if course was disabled
    if @course.disabled? && !@cud.has_auth_level?(:instructor)
      flash[:error] = "Your course has been disabled by your instructor.
                       Please contact them directly if you have any questions"
      redirect_to(controller: :home, action: :error) && return
    end

    # should be able to unsudo from an invalid user and
    # an invalid user should be able to make himself valid through edit page
    invalid_cud = !@cud.valid?
    nicknameless_student = @cud.student? && @cud.nickname.blank?
    in_edit_or_unsudo = (params[:controller] == "course_user_data") &&
                        (params[:action] == "edit" || params[:action] == "update" ||
                         params[:action] == "unsudo")

    return unless (invalid_cud || nicknameless_student) && !in_edit_or_unsudo

    flash[:error] = "Please complete all of your account information before continuing:"
    @cud.errors.full_messages.each do |msg|
      flash[:error] += "<br>#{msg}"
    end
    redirect_to([:edit, @course, @cud]) && return
  end

  ##
  # this loads the current assessment.  It's up to sub-controllers to call this
  # as a before_action when they need the assessment.
  #
  def set_assessment
    begin
      @assessment = @course.assessments.find_by!(name: params[:assessment_name] || params[:name])
    rescue
      flash[:error] = "The assessment was not found for this course."
      redirect_to(action: :index) && return
    end

    redirect_to(action: :index) && return if @cud.student? && !@assessment.released?

    @breadcrumbs << (view_context.current_assessment_link)
  end

  # Loads the submission from the DB
  # needed by the various methods for dealing with submissions.
  # Redirects to the error page if it encounters an issue.
  def set_submission
    begin
      @submission = @assessment.submissions.find(params[:submission_id] || params[:id])
    rescue
      flash[:error] = "Could not find submission with id #{params[:submission_id] || params[:id]}."
      redirect_to([@course, @assessment]) && return
    end

    unless @cud.instructor || @cud.course_assistant ||
           @submission.course_user_datum_id == @cud.id
      flash[:error] = "You do not have permission to access this submission."
      redirect_to([@course, @assessment]) && return
    end

    if (@assessment.exam? || @course.exam_in_progress?) &&
       !(@cud.instructor || @cud.course_assistant)
      flash[:error] = "You cannot view this submission.
              Either an exam is in progress or this is an exam submission."
      redirect_to([@course, @assessment]) && return
    end
    true
  end

  def run_scheduler
    actions = Scheduler.where("next < ?", Time.now)
    actions.each do |action|
      action.next = Time.now + action.interval
      action.save
      Rails.logger.info("Executing #{Rails.root.join(action.action)}")
      begin
        pid = fork do
          # child process
          @course = action.course
          COURSE_LOGGER.setCourse(@course)
          mod_name = Rails.root.join(action.action)
          begin
            require mod_name
            Updater.update(@course)
          rescue ScriptError, StandardError => e
            Rails.logger.error("Error in '#{@course.name}' updater: #{e.message}")
            Rails.logger.error(e.backtrace.inspect)
            ExceptionNotifier.notify_exception(e, data: {action_script: action.action, course: @course})
          end
        end

        Process.detach(pid)
      rescue StandardError => e
        Rails.logger.error("Cannot fork '#{@course.name}' updater: #{e.message}")
        ExceptionNotifier.notify_exception(e)
      end
    end
  end

  def update_persistent_announcements
    @persistent_announcements = Announcement.where(persistent: true)
                                            .where("course_id = ? OR system = ?", @course.id, true)
  end

  def set_breadcrumbs
    @breadcrumbs = []
    return unless @course

    if @course.disabled?
      @breadcrumbs << (view_context.link_to "#{@course.full_name} (Course Disabled)",
                                            [@course], id: "courseTitle")
    else
      @breadcrumbs << (view_context.link_to @course.full_name, [@course], id: "courseTitle")
    end
  end

  def pluralize(count, singular, plural = nil)
    "#{count || 0} " +
      ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
  end

  # make_dlist - Creates a string of emails that can be added as b/cc field.
  # @param section The section to email.  nil if we should email the entire
  # class.
  # @return The filename of the dlist that was created.
  def make_dlist(cuds)
    emails = []

    cuds.each do |cud|
      emails << "#{cud.user.email}"
    end

    emails.join(",")
  end

private

  # called on Exceptions.  Shows a stack trace to course assistants, and above.
  # Shows good ol' Donkey Kong to students
  def render_error(exception)
    # use the exception_notifier gem to send out an e-mail
    # to the notification list specified in config/environment.rb
    ExceptionNotifier.notify_exception(exception, env: request.env,
                                       data: {
                                         user: current_user,
                                         course: @course,
                                         assessment: @assessment,
                                         submission: @submission
                                       })

    respond_to do |format|
       format.html {
          # stack traces are only shown to instructors and administrators
          # by leaving @error undefined, students and CAs do not see stack traces
          if (!current_user.nil?) && (current_user.instructor? || current_user.administrator?)
            @error = exception

            # Generate course id and assesssment id objects
            @course_name = params[:course_name] ||
                           (params[:controller] == "courses" ? params[:name] : nil)
            if @course_name
              @assessment_name = params[:assessment_name] ||
                                 (params[:controller] == "assessments" ? params[:name] : nil)

            end
          end

          render "home/error"
       }
       format.json { head :internal_server_error }
       format.js { head :internal_server_error }
    end
  end
end
