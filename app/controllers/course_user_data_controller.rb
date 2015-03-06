class CourseUserDataController < ApplicationController

  action_auth_level :index, :student
  def index
    @requestedUser = @cud
    render :action=>:show
  end

  action_auth_level :new, :instructor
  def new
    @newCUD = @course.course_user_data.new
    @newCUD.user = User.new
    @newCUD.tweak = Tweak.new
  end

  action_auth_level :create, :instructor
  def create
    @newCUD = @course.course_user_data.new(cud_params)

    # check user existence
    email = params[:course_user_datum][:user_attributes][:email]
    user = User.where(email: email).first
    if user.nil? then

      auth = Authentication.new
      auth.provider = "CMU-Shibboleth"
      auth.uid = email
      auth.save!
      @newUser = User.new(cud_params[:user_attributes])
      @newUser.authentications << auth

      temp_pass = Devise.friendly_token[0, 20]    # generate a random token
      @newUser.password = temp_pass

      if @newUser.save then
         @newCUD.user = @newUser
      else
        @newUser.errors.each do |msg|
          print msg
        end
        flash[:error] = "The user with email #{email} could not be created  "
        redirect_to action: 'new' and return
      end

    else
      # check CUD existence
      if !user.course_user_data.where(course: @course).empty? then
        flash[:error] = "User #{email} is already in #{@course.display_name}"
        redirect_to action: 'new' and return
      end
      @newCUD.user = user
    end

    # save CUD
    if @newCUD.save then
      flash[:success] = "Success: added user #{email} in #{@course.display_name}"
      if @cud.user.administrator?
        redirect_to course_users_path and return
      else
        redirect_to action: 'new' and return
      end
    else
      flash[:error] = "Adding user failed. Check all fields"
      redirect_to action: 'new' and return
    end

  end

  action_auth_level :show, :student
  def show
    @requestedUser = @cud.course.course_user_data.find(params[:id])
    respond_to do |format|
      if @requestedUser
        format.html
        format.json { render :json => @requestedUser.to_json }
      else
        format.json { head :bad_request }
      end
    end
  end

  action_auth_level :edit, :student
  def edit
    @editCUD = @course.course_user_data.find(params[:id])
    if @editCUD == nil then
      flash[:error] = "Can't find user in the course."
      redirect_to :action=>"index" and return
    end

    if (@editCUD.id != @cud.id) and (!@cud.instructor?) and
        (!@cud.user.administrator?) then
      flash[:error] = "Permission denied."
      redirect_to :action=>"index" and return
    end

    @editCUD.tweak ||= Tweak.new
  end

  action_auth_level :update, :student
  def update
    # ensure presence of nickname
    # isn't a User model validation since users can start off without nicknames
    # application_controller's authenticate_user redirects here if nickname isn't set
    @editCUD = @course.course_user_data.find(params[:id])
    if @editCUD == nil then
      redirect_to :action=>"index" and return
    end

    if (@cud.student?) then
      if (@editCUD.id != @cud.id) then
        redirect_to action: :index and return
      else
        @editCUD.nickname = params[:course_user_datum][:nickname]
        if @editCUD.save then
          redirect_to action: :show and return
        else
          redirect_to action: :edit and return
        end
      end
    end
    
    # editor is not a student at this point
    # won't have tweak attributes if student is editing
    tweak_attrs = params[:course_user_datum][:tweak_attributes]
    if tweak_attrs && tweak_attrs[:value].blank? then
      params[:course_user_datum][:tweak_attributes][:_destroy] = true
    end

    # When we're finished editing, go back to the user table
    if @editCUD.update!(edit_cud_params) then
      flash[:success] = "Success: Updated user #{@editCUD.email}"
      redirect_to [@course, @editCUD] and return
    else
      flash[:error] = "Update failed. Check all fields"
      redirect_to action: :edit and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @destroyCUD = @course.course_user_data.find(params[:id])
    if @destroyCUD and @destroyCUD != @cud and params[:yes1] and params[:yes2] and params[:yes3] then
      @destroyCUD.destroy() #awwww!!!
    end
    redirect_to course_users_path(@course) and return
  end

  # Non-RESTful paths below

  # this GET page confirms that the instructor wants to destroy the user
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm
    @destroyCUD = @course.course_user_data.find(params[:course_user_datum_id])
  end

  action_auth_level :sudo, :instructor
  def sudo
    if not (@cud.can_sudo? or session[:sudo]) then
      redirect_to course_path(@cud.course.id) and return
    end

    if request.post? then
      sudo_user = User.where(email: params[:sudo_email]).first
      if not sudo_user then
        flash[:error] = "User #{params[:sudo_email]} does not exist."
        redirect_to course_path(@cud.course.id) and return
      end

      sudo_cud = @course.course_user_data.where(user_id: sudo_user.id).first
      if not sudo_cud then
        flash[:error] = "User #{params[:sudo_email]} does not exist."
        redirect_to course_path(@cud.course.id) and return
      end

      if not @cud.can_sudo_to?(sudo_cud) then
        flash[:error] = "You do not have the privileges to act as " +
                "#{sudo_cud.display_name}."
        redirect_to course_path(@cud.course.id) and return
      end

      if @cud.id == sudo_cud.id then
        flash[:error] = "There's no point in trying to act as yourself."
        redirect_to course_path(@cud.course.id) and return
      end

      session[:sudo] = {}
      session[:sudo][:user_id] = sudo_cud.user.id
      session[:sudo][:course_id] = sudo_cud.course.id

      # this was sudo_cud.display_name
      session[:sudo][:actual_name] = @cud.display_name

      redirect_to course_path(@cud.course.id) and return
    end
  end

  action_auth_level :unsudo, :student
  def unsudo
    session[:sudo] = nil
    redirect_to course_path(@cud.course.id)
  end

private

  def cud_params
    if @cud.administrator? then
      params.require(:course_user_datum).permit(:school, :major, :year,
        :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
        :user_attributes => [:first_name, :last_name, :email],
        tweak_attributes: [:_destroy, :kind, :value])
    elsif @cud.instructor? then
      params.require(:course_user_datum).permit(:school, :major, :year,
        :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
        :user_attributes=>[:email, :first_name, :last_name],
        tweak_attributes: [:_destroy, :kind, :value])
    else
      params.require(:course_user_datum).permit(:nickname) #,
#        user_attributes: [:first_name, :last_name])
    end
  end

  def edit_cud_params
    if @cud.administrator? then
      params.require(:course_user_datum).permit(:school, :major, :year,
        :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
        :user_attributes => [:id, :email, :first_name, :last_name],
        tweak_attributes: [:_destroy, :kind, :value])
    elsif @cud.instructor? then
      params.require(:course_user_datum).permit(:school, :major, :year,
        :lecture, :section, :instructor, :dropped, :nickname, :course_assistant,
        :user_attributes=>[:id, :email, :first_name, :last_name],
        tweak_attributes: [:_destroy, :kind, :value])
    else
      params.require(:course_user_datum).permit(:nickname) #user_attributes: [:first_name, :last_name])
    end
  end

end

