class CourseUserDataController < ApplicationController
  before_action :add_users_breadcrumb

    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :index, :student
  def index
    @requestedUser = @cud
    render action: :show
  end

  action_auth_level :new, :instructor
  def new
    @newCUD = @course.course_user_data.new
    @newCUD.user = User.new
    @newCUD.tweak = Tweak.new
  end

  action_auth_level :create, :instructor
  def create
    cud_parameters = cud_params
    @newCUD = @course.course_user_data.new(cud_parameters)

    # check user existence
    email = cud_parameters[:user_attributes][:email]
    user = User.where(email: email).first
    if user.nil?
      user = User.roster_create(email,
                                cud_parameters[:user_attributes][:first_name],
                                cud_parameters[:user_attributes][:last_name],
                                "", "", "")

      if user
        @newCUD.user = user
      else
        flash[:error] = "The user with email #{email} could not be created  "
        redirect_to(action: "new") && return
      end

    else
      # check CUD existence
      unless user.course_user_data.where(course: @course).empty?
        flash[:error] = "User #{email} is already in #{@course.full_name}"
        redirect_to(action: "new") && return
      end
      @newCUD.user = user
    end

    # save CUD
    if @newCUD.save
      flash[:success] = "Success: added user #{email} in #{@course.full_name}"
      if @cud.user.administrator?
        redirect_to([:users, @course]) && return
      else
        redirect_to(action: "new") && return
      end
    else
      flash[:error] = "Adding user failed. Check all fields"
      redirect_to(action: "new") && return
    end
  end

  action_auth_level :show, :student
  def show
    @requestedUser = @cud.course.course_user_data.find(params[:id])
    respond_to do |format|
      if @requestedUser
        format.html
        format.json { render json: @requestedUser.to_json }
      else
        format.json { head :bad_request }
      end
    end
  end

  action_auth_level :edit, :student
  def edit
    @editCUD = @course.course_user_data.find(params[:id])
    if @editCUD.nil?
      flash[:error] = "Can't find user in the course."
      redirect_to(action: "index") && return
    end

    if (@editCUD.id != @cud.id) && (!@cud.instructor?) &&
       (!@cud.user.administrator?)
      flash[:error] = "Permission denied."
      redirect_to(action: "index") && return
    end

    @editCUD.tweak ||= Tweak.new
  end

  action_auth_level :update, :student
  def update
    # ensure presence of nickname
    # isn't a User model validation since users can start off without nicknames
    # application_controller's authenticate_user redirects here if nickname isn't set
    @editCUD = @course.course_user_data.find(params[:id])
    redirect_to(action: "index") && return if @editCUD.nil?

    if @cud.student?
      if (@editCUD.id != @cud.id)
        redirect_to(action: :index) && return
      else
        @editCUD.nickname = params[:course_user_datum][:nickname]
        if @editCUD.save
          redirect_to(action: :show) && return
        else
          flash[:error] = "Please complete all of your account information before continuing:"
          @editCUD.errors.full_messages.each do |msg|
            flash[:error] += "<br>#{msg}"
          end
          redirect_to(action: :edit) && return
        end
      end
    end

    # editor is not a student at this point
    # won't have tweak attributes if student is editing
    tweak_attrs = params[:course_user_datum][:tweak_attributes]
    if tweak_attrs && tweak_attrs[:value].blank?
      params[:course_user_datum][:tweak_attributes][:_destroy] = true
    end

    # When we're finished editing, go back to the user table
    if @editCUD.update(edit_cud_params)
      flash[:success] = "Success: Updated user #{@editCUD.email}"
      redirect_to([@course, @editCUD]) && return
    else
      flash[:error] = "Update failed. Check all fields"
      redirect_to(action: :edit) && return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @destroyCUD = @course.course_user_data.find(params[:id])
    if @destroyCUD && @destroyCUD != @cud && params[:yes1] && params[:yes2] && params[:yes3]
      @destroyCUD.destroy # awwww!!!
    end
    redirect_to([:users, @course]) && return
  end

  # Non-RESTful paths below

  # this GET page confirms that the instructor wants to destroy the user
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm
    @destroyCUD = @course.course_user_data.find(params[:id])
  end

  action_auth_level :sudo, :instructor
  def sudo
    redirect_to([@cud.course]) && return unless @cud.can_sudo? || session[:sudo]

    return unless request.post?

    sudo_user = User.where(email: params[:sudo_email]).first
    unless sudo_user
      flash[:error] = "User #{params[:sudo_email]} does not exist."
      redirect_to([@cud.course]) && return
    end

    sudo_cud = @course.course_user_data.where(user_id: sudo_user.id).first
    unless sudo_cud
      flash[:error] = "User #{params[:sudo_email]} does not exist."
      redirect_to([@cud.course]) && return
    end

    unless @cud.can_sudo_to?(sudo_cud)
      flash[:error] = "You do not have the privileges to act as " \
              "#{sudo_cud.display_name}."
      redirect_to([@cud.course]) && return
    end

    if @cud.id == sudo_cud.id
      flash[:error] = "There's no point in trying to act as yourself."
      redirect_to([@cud.course]) && return
    end

    session[:sudo] = {}
    session[:sudo][:user_id] = sudo_cud.user.id
    session[:sudo][:course_id] = sudo_cud.course.id

    # this was sudo_cud.display_name
    session[:sudo][:actual_name] = @cud.display_name

    redirect_to([@cud.course]) && return
  end

  action_auth_level :unsudo, :student
  def unsudo
    session[:sudo] = nil
    redirect_to([@cud.course]) && return
  end

private

  def add_users_breadcrumb
    if @cud.instructor
      @breadcrumbs << (view_context.link_to "Users", [:users, @course])
    end
  end

  def cud_params
    if @cud.administrator?
      params.require(:course_user_datum).permit(:school, :major, :year,
                                                :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
                                                user_attributes: [:first_name, :last_name, :email],
                                                tweak_attributes: [:_destroy, :kind, :value])
    elsif @cud.instructor?
      params.require(:course_user_datum).permit(:school, :major, :year,
                                                :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
                                                user_attributes: [:email, :first_name, :last_name],
                                                tweak_attributes: [:_destroy, :kind, :value])
    else
      params.require(:course_user_datum).permit(:nickname) # ,
      #        user_attributes: [:first_name, :last_name])
    end
  end

  def edit_cud_params
    if @cud.administrator?
      params.require(:course_user_datum).permit(:school, :major, :year,
                                                :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
                                                user_attributes: [:id, :email, :first_name, :last_name],
                                                tweak_attributes: [:_destroy, :kind, :value])
    elsif @cud.instructor?
      params.require(:course_user_datum).permit(:school, :major, :year,
                                                :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
                                                user_attributes: [:id, :email, :first_name, :last_name],
                                                tweak_attributes: [:_destroy, :kind, :value])
    else
      params.require(:course_user_datum).permit(:nickname) # user_attributes: [:first_name, :last_name])
    end
  end
end
