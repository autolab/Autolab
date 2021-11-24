class UsersController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements
  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end
  before_action :set_gh_oauth_client, only: [:github_oauth, :github_oauth_callback]
  before_action :set_user, only: [:github_oauth, :github_revoke]

  # GET /users
  action_auth_level :index, :student
  def index
    if current_user.administrator?
      @users = User.all.sort_by(&:email)
    else
      users = [current_user]
      cuds = current_user.course_user_data

      cuds.each do |cud|
        users |= cud.course.course_user_data.collect(&:user) if cud.instructor?
      end

      @users = users.sort_by(&:email)
    end
  end

  # GET /users/id
  # show the info of a user together with his cuds
  # based on current user's role
  action_auth_level :show, :student
  def show
    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "User does not exist"
      redirect_to(users_path) && return
    end

    if current_user.administrator?
      # if current user is admin, show whatever he requests
      @user = user
      @cuds = user.course_user_data
    else
      # look for cud in courses where current user is instructor of
      cuds = current_user.course_user_data
      user_cuds = []

      cuds.each do |cud|
        next unless cud.instructor?

        user_cud =
          cud.course.course_user_data.where(user: user).first
        user_cuds << user_cud unless user_cud.nil?
      end

      if !user_cuds.empty?
        # current user is instructor to user
        @user = user
        @cuds = user_cuds
      elsif user != current_user
        # current user is not instructor to user
        flash[:error] = "Permission denied"
        redirect_to(users_path) && return
      else
        @user = current_user
        @cuds = current_user.course_user_data
      end
    end
  end

  # GET users/new
  # only adminstrator and instructors are allowed
  action_auth_level :new, :instructor
  def new
    if current_user.administrator? || current_user.instructor?
      @user = User.new
    else
      # current user is a normal user. Permission denied
      flash[:error] = "Permission denied"
      redirect_to(users_path) && return
    end
  end

  # POST users/create
  # create action for instructors or above.
  # send out an email to new user on success
  action_auth_level :create, :instructor
  def create
    if current_user.administrator?
      @user = User.new(admin_new_user_params)
    elsif current_user.instructor?
      @user = User.new(new_user_params)
    else
      # current user is a normal user. Permission denied
      flash[:error] = "Permission denied"
      redirect_to(users_path) && return
    end

    temp_pass = Devise.friendly_token[0, 20] # generate a random token
    @user.password = temp_pass
    @user.password_confirmation = temp_pass
    @user.skip_confirmation!
    save_worked = false
    begin
      save_worked = @user.save
      flash[:error] = "User creation failed" unless save_worked
    rescue StandardError => e
      error_message = e.message
      flash[:error] = if error_message.include? "Duplicate entry" and error_message.include? "@"
                        "User with email #{@user.email} already exists"
                      else
                        "User creation failed"
                      end
      save_worked = false
    end
    if save_worked
      @user.send_reset_password_instructions
      flash[:success] = "User creation success"
      redirect_to(users_path) && return
    else
      render action: "new"
    end
  end

  # GET users/:id/edit
  action_auth_level :edit, :student
  def edit
    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "User does not exist"
      redirect_to(users_path) && return
    end

    if current_user.administrator?
      @user = user
    elsif user != current_user
      # current user can only edit himself if he's neither role
      flash[:error] = "Permission denied"
      redirect_to(users_path) && return
    else
      @user = current_user
    end
  end

  # PATCH users/:id/
  action_auth_level :update, :student
  def update
    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "User does not exist"
      redirect_to(users_path) && return
    end

    if current_user.administrator? ||
       current_user.instructor_of?(user)
      @user = user
    elsif user != current_user
      # current user can only edit himself if he's neither role
      flash[:error] = "Permission denied"
      redirect_to(users_path) && return
    else
      @user = current_user
    end

    if user.update(if current_user.administrator?
                     admin_user_params
                   else
                     user_params
                   end)
      flash[:success] = "User was successfully updated."
      redirect_to(users_path) && return
    else
      flash[:error] = "User update failed. Check all fields"
      redirect_to(edit_user_path(user)) && return
    end
  end

  # DELETE users/:id/
  action_auth_level :destroy, :administrator
  def destroy
    unless current_user.administrator?
      flash[:error] = "Permission denied."
      redirect_to(users_path) && return
    end

    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "User doesn't exist."
      redirect_to(users_path) && return
    end

    # TODO: Need to cleanup user resources here

    user.destroy
    flash[:success] = "User destroyed."
    redirect_to(users_path) && return
  end

  action_auth_level :github_oauth, :student
  def github_oauth
    github_integration = GithubIntegration.find_by_user_id(@user.id)
    state = SecureRandom.alphanumeric(128)
    if github_integration.nil?
      github_integration = GithubIntegration.create!(oauth_state: state, user: @user)
    else
      github_integration.update!(oauth_state: state)
    end
    # Use https, unless explicitly specified not to
    prefix = "https://"
    if ENV["DOCKER_SSL"] == "false"
      prefix = "http://"
    end

    begin
      if Rails.env.development?
        hostname = request.base_url
      else
        hostname = prefix + request.host
      end
    rescue
      hostname = `hostname`
      hostname = prefix + hostname.strip
    end

    authorize_url_params = {
      redirect_uri: "#{hostname}/users/github_oauth_callback",
      scope: "repo",
      state: state
    }
    redirect_to @gh_client.auth_code.authorize_url(authorize_url_params)
  end

  action_auth_level :github_oauth_callback, :student
  def github_oauth_callback
    if params["error"] 
      flash[:error] = "User cancelled OAuth"
      (redirect_to(root_path)) && return
    end

    # If state not recognized, this request may not have been generated from Autolab
    if params["state"].nil? || params["state"].empty?
      flash[:error] = "Invalid callback"
      (redirect_to(root_path)) && return
    end

    github_integration = GithubIntegration.find_by_oauth_state(params["state"])
    if github_integration.nil?
      flash[:error] = "Error with Github OAuth (invalid state), please try again."
      (redirect_to(root_path)) && return
    end

    begin
      # Results in exception if invalid
      token = @gh_client.auth_code.get_token(params["code"])
    rescue StandardError => e
      flash[:error] = "Error with Github OAuth (invalid code), please try again."
      github_integration.update!(oauth_state: nil)
      (redirect_to user_path(id: oauth_user.id)) && return
    end

    access_token = token.to_hash[:access_token]
    github_integration.update!(access_token: access_token, oauth_state: nil)
    flash[:success] = "Successfully connected with Github."
    (redirect_to (root_path)) && return
  end

  action_auth_level :github_revoke, :student
  def github_revoke
    gh_integration = @user.github_integration
    if gh_integration
      gh_integration.revoke
      gh_integration.destroy
      flash[:success] = "Successfully disconnected from Github"
    elsif
      flash[:info] = "Github not connected, revocation unnecessary"
    end
    (redirect_to user_path(id: @user.id)) && return
  end

private

  def new_user_params
    params.require(:user).permit(:email, :first_name, :last_name)
  end

  def admin_new_user_params
    params.require(:user).permit(:email, :first_name, :last_name, :administrator)
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name)
  end

  # user params that admin is allowed to edit
  def admin_user_params
    params.require(:user).permit(:first_name, :last_name, :administrator)
  end

  def set_gh_oauth_client
    gh_options = {
      :authorize_url => "https://github.com/login/oauth/authorize",
      :token_url => "https://github.com/login/oauth/access_token",
      :site => "https://github.com",
    }
    @gh_client = OAuth2::Client.new(Rails.configuration.x.github.client_id, Rails.configuration.x.github.client_secret,
                                    gh_options)
  end

  def set_user
    @user = User.find(params[:id])
    if @user.nil?
      flash[:error] = "User doesn't exist."
      redirect_to(user_path) && return
    end
  end
end
