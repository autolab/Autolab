# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  before_action :configure_permitted_paramters, if: :devise_controller?
  before_action :maintenance_mode? 
  before_action :run_scheduler

  before_action :authenticate_user!
  before_action :authorize_user_for_course, except: [:action_no_auth ]
  before_action :authenticate_for_action
  before_action :update_persistent_announcements

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
      flash[:error] = e.user_message
      redirect_to root_path
    end
  end  

  def self.autolabRequire(path)
    if (Rails.env == "development") then 
      $".delete(path)
    end
    require(path)
  end

  @@global_whitelist = {}
  def self.action_auth_level(action, level)
    raise ArgumentError.new("The action must be specified.") if action.nil?
    raise ArgumentError.new("The action must be symbol.") unless action.is_a? Symbol
    raise ArgumentError.new("The level must be specified.") if level.nil?
    raise ArgumentError.new("The level must be symbol.") unless level.is_a? Symbol
    unless CourseUserDatum::AUTH_LEVELS.include?(level)
      raise ArgumentError.new("#{level.to_s} is not an auth level") 
    end

    if level == :administrator then
      skip_before_filter :authorize_user_for_course, only: [action]
      skip_filter :authenticate_for_action => [action]
      skip_before_filter :update_persistent_announcements, only: [action]
    end

    controller_whitelist = (@@global_whitelist[self.controller_name.to_sym] ||= {})
    raise ArgumentError.new("#{action.to_s} already specified.") if controller_whitelist[action]

    controller_whitelist[action] = level
  end

  def self.action_no_auth(action)
    skip_before_action :verify_authenticity_token, :authenticate_user!
    skip_filter :configure_permitted_paramters => [action]
    skip_filter :maintenance_mode => [action]
    skip_filter :run_scheduler => [action]

    skip_filter :authenticate_user => [action]
    skip_before_filter :authorize_user_for_course, only: [action]
    skip_filter :authenticate_for_action => [action]
    skip_before_filter :update_persistent_announcements, only: [action]
  end

protected
  
  def configure_permitted_paramters
    devise_parameter_sanitizer.for(:sign_in) { |u| u.permit(:email) }
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:email, :first_name, :last_name, :password, :password_confirmation) }
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:email, :password, :password_confirmation, :current_password) }
  end


  def authentication_failed(user_message=nil, dev_message=nil)
    user_message ||= "You are not authorized to view this page"

    if user_signed_in?
      dev_message ||= "For user #{current_user.email}"
    else
      dev_message ||= "Before initial user authentication."
    end

    raise CourseUserDatum::AuthenticationFailed.new(user_message, dev_message)
  end

  def authenticate_for_action
    controller_whitelist = @@global_whitelist[params[:controller].to_sym]
    return if controller_whitelist.nil?

    level = controller_whitelist[params[:action].to_sym]
    return if level.nil?

    if level == :administrator then
      authentication_failed unless current_user.administrator
    else
      authentication_failed unless @cud.has_auth_level?(level)
    end
  end

  protect_from_forgery 
  def verify_authenticity_token
    msg = "Invalid request! Please go back, reload the " +
        "page and try again.  If you continue to see this error. " +
        " please contact the Autolab Development team at the " + 
        "contact link below" 

    if not verified_request? then 
      authentication_failed(msg)
    end
  end

  def maintenance_mode?
    # enable/disable maintenance mode with this switch:
    if false
      unless @user.administrator?
        redirect_to "/maintenance.html"
      end
    end
  end

  # def authenticate_user
  #   # development
  #   if Rails.env == "development"
  #     if cookies[:dev_user] then
  #       @username = cookies[:dev_user]
  #     else
  #       redirect_to controller: :home, action: :developer_login and return
  #     end
  # 
  #   # production
  #   else
  #     # request.remote_user set by Shibboleth (WebLogin)
  #     if request.remote_user
  #       @username = request.remote_user.split("@")[0]
  #     else
  #       flash[:error] = "You are not logged in?"
  #       redirect_to :controller => :home, :action => :error and return
  #     end
  #   end
  # end

  def authorize_user_for_course
    course_id = params[:course_id] ||
          (params[:controller] == "courses" ? params[:id] : nil)
    if (course_id) then
      @course = Course.find(course_id)
    end

    unless @course
      flash[:error] = "Course #{params[:course]} does not exist!"
      redirect_to controller: :home, action: :error and return
    end

    # set course logger
    begin
      COURSE_LOGGER.setCourse(@course)
    rescue Exception => e
      flash[:error] = e.to_s
      redirect_to controller: :home, action: :error and return
    end

    if current_user.nil? then
      redirect_to root_path and return
    end
    uid = current_user.id
    # don't allow sudoing across courses
    if (session[:sudo]) then
      if (@course.id == session[:sudo]["course_id"]) then
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
      redirect_to controller: :home, action: :error and return

    when :unauthorized
      flash[:error] = "User #{current_user.email} is not in this course"
      redirect_to controller: :home, action: :error and return
    end

    # check if course was disabled
    if @course.disabled? and !@cud.has_auth_level?(:instructor) then
      flash[:error] = "Your course has been disabled by your instructor. Please contact them directly if you have any questions"
      redirect_to controller: :home, action: :error and return
    end

    # should be able to unsudo from an invalid user and
    # an invalid user should be able to make himself valid through edit page
    invalid_cud = !@cud.valid?
    nicknameless_student = @cud.student? && @cud.nickname.blank?
    in_edit_or_unsudo = (params[:controller] == "course_user_data") &&
                        (params[:action] == "edit" or params[:action] == "update" or
                         params[:action] == "unsudo")

    if (invalid_cud or nicknameless_student) and !in_edit_or_unsudo then 
      flash[:error] = "Please complete all of your account information before continuing"
      redirect_to edit_course_course_user_datum_path(id: @cud.id, course_id: @cud.course.id)
    end
  end

  def run_scheduler

    actions = Scheduler.where("next < ?",Time.now())
    for action in actions do 
      action.next = Time.now + action.interval
      action.save()
      puts "Executing #{File.join(Rails.root,action.action)}"
      begin
        pid = fork do
          # child process
          @course = action.course
          modName = File.join(Rails.root,action.action)
          require "#{modName}"
          Updater.update(@course)
        end

        Process.detach(pid)
      rescue Exception => e  
        COURSE_LOGGER.log("Error updater: #{e.to_s}")
        puts e
        puts e.message  
        puts e.backtrace.inspect
      end
    end
  end
  
  def update_persistent_announcements
    @persistent_announcements = Announcement.where("persistent and (course_id=? or system)", @course.id)
  end

  def pluralize(count, singular, plural = nil)
    "#{count || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
  end

  # makeDlist - Creates a string of emails that can be added as b/cc field.
  # @param section The section to email.  nil if we should email the entire
  # class. 
  # @return The filename of the dlist that was created. 
  def makeDlist(cuds)
    emails = []

    for cud in cuds do 
      emails << "#{cud.user.email}"
    end

    return emails.join(",")
  end

private

  # called on Exceptions.  Shows a stack trace to course assistants, and above.
  # Shows good ol' Donkey Kong to students
  def render_error(exception)
    # use the exception_notifier gem to send out an e-mail to the notification list specified in config/environment.rb
    ExceptionNotifier.notify_exception(exception, env: request.env, data: {message: "was doing something wrong"})

    # stack traces are only shown to instructors and administrators
    # by leaving @error undefined, students and CAs do not see stack traces
    if (not current_user.nil?) and (current_user.instructor? or current_user.administrator?) then
      @error = exception

      # Generate course id and assesssment id objects
      @course_id = params[:course_id] ||
            (params[:controller] == "courses" ? params[:id] : nil)
      if (@course_id) then
        @assessment_id = params[:assessment_id] ||
            (params[:controller] == "assessments" ? params[:id] : nil)
      end
    end

    render "home/error"
  end

end
