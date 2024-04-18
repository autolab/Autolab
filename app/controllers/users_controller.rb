class UsersController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements
  before_action :set_gh_oauth_client, only: [:github_oauth, :github_oauth_callback]
  before_action :set_user,
                only: [:github_oauth, :github_revoke, :lti_launch_initialize,
                       :lti_launch_link_course]
  before_action :set_users_list_breadcrumb, except: %i[index]

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
    user = User.find_by id: params[:id]
    if user.nil?
      flash[:error] = "Failed to show user: user does not exist."
      redirect_to(users_path) && return
    end

    @hover_assessment_date = user.hover_assessment_date

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
          cud.course.course_user_data.where(user:).first
        user_cuds << user_cud unless user_cud.nil?
      end

      if !user_cuds.empty?
        # current user is instructor to user
        @user = user
        @cuds = user_cuds
      elsif user != current_user
        # current user is not instructor to user
        flash[:error] = "Permission denied: you are not allowed to view this user."
        redirect_to(users_path) && return
      else
        @user = current_user
        @cuds = current_user.course_user_data
      end
    end
  end

  # GET users/new
  # only administrator and instructors are allowed
  action_auth_level :new, :instructor
  def new
    if current_user.administrator? || current_user.instructor?
      @user = User.new
    else
      # current user is a normal user. Permission denied
      flash[:error] = "Permission denied: you are not allowed to view this page."
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
      flash[:error] = "Permission denied: you are not allowed to view this page."
      redirect_to(users_path) && return
    end

    temp_pass = Devise.friendly_token[0, 20] # generate a random token
    @user.password = temp_pass
    @user.password_confirmation = temp_pass
    @user.skip_confirmation!
    save_worked = false
    begin
      save_worked = @user.save
      flash[:error] = "Failed to create user." unless save_worked
    rescue StandardError => e
      error_message = e.message
      flash[:error] = if error_message.include?("Duplicate entry") && error_message.include?("@")
                        "Failed to create user: User with email #{@user.email} already exists."
                      else
                        "Failed to create user."
                      end
      save_worked = false
    end
    if save_worked
      @user.send_reset_password_instructions
      flash[:success] = "Successfully created user."
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
      flash[:error] = "Failed to edit user: user does not exist."
      redirect_to(users_path) && return
    end

    if current_user.administrator?
      @user = user
    elsif user != current_user
      # current user can only edit himself if he's neither role
      flash[:error] = "Permission denied: you are not allowed to edit this user."
      redirect_to(users_path) && return
    else
      @user = current_user
    end

    # Do it ad-hoc here, since this is the only place we need it
    @breadcrumbs << (view_context.link_to @user.display_name, user_path(@user))
  end

  action_auth_level :download_all_submissions, :student
  def download_all_submissions
    user = User.find(params[:id])
    submissions = if params[:final]
                    Submission.latest.where(course_user_datum: CourseUserDatum.where(user_id: user))
                  else
                    Submission.where(course_user_datum: CourseUserDatum.where(user_id: user))
                  end
    submissions = submissions.select do |s|
      p = s.handin_file_path
      is_disabled = s.course_user_datum.course.is_disabled?
      !p.nil? && File.exist?(p) && File.readable?(p) && !is_disabled
    end
    if submissions.empty?
      flash[:error] = "There are no submissions to download."
      redirect_to(user_path(user)) && return
    end

    current_time = Time.current
    filename = if params[:final]
                 "autolab_final_submissions_#{current_time.strftime('%Y-%m-%d')}"
               else
                 "autolab_all_submissions_#{current_time.strftime('%Y-%m-%d')}"
               end

    temp_file = Tempfile.new("autolab_submissions.zip")
    Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
      submissions.each do |s|
        p = s.handin_file_path
        course_name = s.course_user_datum.course.name
        assignment_name = s.assessment.name
        course_directory = "#{filename}/#{course_name}"
        assignment_directory = "#{course_directory}/#{assignment_name}"
        entry_name = download_filename(p, assignment_name)
        zipfile.add(File.join(assignment_directory, entry_name), p)
      end
    end

    send_file(temp_file.path,
              type: "application/zip",
              disposition: "attachment", # tell browser to download
              filename: "#{filename}.zip")
  end

  # PATCH users/:id/
  action_auth_level :update, :student
  def update
    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "Failed to update user: user does not exist."
      redirect_to(users_path) && return
    end

    if current_user.administrator? ||
       current_user.instructor_of?(user)
      @user = user
    elsif user != current_user
      # current user can only edit himself if he's neither role
      flash[:error] = "Permission denied: you are not allowed to update this user."
      redirect_to(users_path) && return
    else
      @user = current_user
    end

    if user.update(if current_user.administrator?
                     admin_user_params
                   else
                     user_params
                   end)
      flash[:success] = "Successfully updated user."
      redirect_to(users_path) && return
    else
      flash[:error] = "Failed to update user. Check all fields and try again."
      redirect_to(edit_user_path(user)) && return
    end
  end

  # DELETE users/:id/
  action_auth_level :destroy, :administrator
  def destroy
    unless current_user.administrator?
      flash[:error] = "Permission denied: you are not allowed to delete this user."
      redirect_to(users_path) && return
    end

    if current_user.id == params[:id].to_i
      flash[:error] = "Failed to delete user: you cannot delete yourself."
      redirect_to(users_path) && return
    end

    user = User.find(params[:id])
    if user.nil?
      flash[:error] = "Failed to delete user: user doesn't exist."
      redirect_to(users_path) && return
    end

    # TODO: Need to cleanup user resources here

    user.destroy
    flash[:success] = "Successfully destroyed user."
    redirect_to(users_path) && return
  end

  def lti_launch_initialize
    unless params[:course_title].present? && params[:context_id].present? &&
           params[:course_memberships_url].present? && params[:platform].present?
      raise LtiLaunchController::LtiError.new("Unable to launch LTI link, missing parameters",
                                              :bad_request)
    end

    linked_lcd = LtiCourseDatum.joins(:course).find_by(context_id: params[:context_id])
    unless linked_lcd.nil?
      flash[:success] = "#{params[:course_title]} already linked"
      redirect_to(course_path(linked_lcd.course)) && return
    end

    courses_for_user = User.courses_for_user @user
    redirect_to(home_no_user_path) && return unless courses_for_user.any?

    @listing = { current: [], completed: [], upcoming: [] }

    courses_for_user.each do |course|
      next if course.is_disabled?

      course_cud = CourseUserDatum.find_cud_for_course(course, @user.id)
      next unless course_cud.has_auth_level?(:course_assistant)

      @listing[course.temporal_status] << course
    end
  end

  action_auth_level :lti_launch_link_course, :instructor
  def lti_launch_link_course
    unless params[:context_id].present? && params[:course_memberships_url].present? &&
           params[:platform].present?
      raise LtiLaunchController::LtiError.new("Unable to link course, missing parameters",
                                              :bad_request)
    end

    LtiCourseDatum.create(
      course_id: params[:course_id],
      context_id: params[:context_id],
      membership_url: params[:course_memberships_url],
      platform: params[:platform],
      last_synced: DateTime.current
    )

    course = Course.find(params[:course_id])
    flash[:success] = "#{course.name} successfully linked."
    redirect_to(course)
  end

  action_auth_level :github_oauth, :student
  def github_oauth
    github_integration = GithubIntegration.find_by(user_id: @user.id)
    state = SecureRandom.alphanumeric(128)
    if github_integration.nil?
      # rubocop:disable Lint/UselessAssignment
      github_integration = GithubIntegration.create!(oauth_state: state, user: @user)
      # rubocop:enable Lint/UselessAssignment
    else
      github_integration.update!(oauth_state: state)
    end
    # Use https, unless explicitly specified not to
    prefix = "https://"
    if ENV["DOCKER_SSL"] == "false"
      prefix = "http://"
    end

    begin
      hostname = if Rails.env.development?
                   request.base_url
                 else
                   prefix + request.host
                 end
    rescue StandardError
      hostname = `hostname`
      hostname = prefix + hostname.strip
    end

    authorize_url_params = {
      redirect_uri: "#{hostname}/users/github_oauth_callback",
      scope: "repo",
      state:
    }
    redirect_to @gh_client.auth_code.authorize_url(authorize_url_params)
  end

  action_auth_level :github_oauth_callback, :student
  def github_oauth_callback
    if params["error"]
      flash[:error] = "User cancelled OAuth"
      redirect_to(root_path) && return
    end

    # If state not recognized, this request may not have been generated from Autolab
    if params["state"].blank?
      flash[:error] = "Invalid callback"
      redirect_to(root_path) && return
    end

    github_integration = GithubIntegration.find_by(oauth_state: params["state"])
    if github_integration.nil?
      flash[:error] = "Error with Github OAuth (invalid state), please try again."
      redirect_to(root_path) && return
    end
    oauth_user = github_integration.user

    begin
      # Results in exception if invalid
      token = @gh_client.auth_code.get_token(params["code"])
    rescue StandardError
      flash[:error] = "Error with Github OAuth (invalid code), please try again."
      github_integration.update!(oauth_state: nil)
      (redirect_to user_path(id: oauth_user.id)) && return
    end

    access_token = token.to_hash[:access_token]
    github_integration.update!(access_token:, oauth_state: nil)
    flash[:success] = "Successfully connected with Github."
    redirect_to(user_path(id: oauth_user.id)) && return
  end

  action_auth_level :github_revoke, :student
  def github_revoke
    gh_integration = @user.github_integration
    if gh_integration
      gh_integration.revoke
      gh_integration.destroy
      flash[:success] = "Successfully disconnected from Github"
    else
      flash[:notice] = "Github not connected, revocation unnecessary"
    end
    (redirect_to user_path(id: @user.id)) && return
  end

  action_auth_level :change_password_for_user, :administrator
  def change_password_for_user
    user = User.find(params[:id])
    raw, enc = Devise.token_generator.generate(User, :reset_password_token)
    user.reset_password_token = enc
    user.reset_password_sent_at = Time.current
    user.save(validate: false)
    Devise.sign_in_after_reset_password = false
    user_reset_link = edit_password_url(user, reset_password_token: raw)
    admin_reset_link = update_password_for_user_user_path(user:)
    flash[:success] =
      "Click " \
      "#{view_context.link_to 'here', admin_reset_link, method: 'get'} " \
      "to reset #{user.display_name}'s password " \
      "<br>Or copy this link for the user to reset their own password: "\
      "#{user_reset_link}"
    flash[:html_safe] = true
    redirect_to(user_path)
  end

  def update_password_for_user
    @user = User.find(params[:id])
    return if params[:user].nil? || params[:user].is_a?(String) || @user.nil?

    if params[:user][:password] != params[:user][:password_confirmation]
      flash[:error] = "Passwords do not match"
    elsif @user.update(password: params[:user][:password])
      flash[:success] = "Password changed successfully"
      redirect_to(root_path)
    else
      flash[:error] = "Password #{@user.errors[:password][0]}"
    end
  end

  action_auth_level :update_display_settings, :student
  def update_display_settings
    @user = current_user
    return if params[:user].nil? || params[:user].is_a?(String) || @user.nil?

    if @user.update(hover_assessment_date: params[:user][:hover_assessment_date])
      flash[:success] = "Successfully updated display settings"
      (redirect_to user_path(id: @user.id)) && return
    else
      flash[:error] = @user.errors[:hover_assessment_date][0].to_s
    end
  end

private

  # Given the path to a file, return the filename to use when the user downloads it
  # path should be of the form .../<ver>_<handin> or .../annotated_<ver>_<handin>
  # returns <course_name>_<assignment_name>_<ver>_<handin>
  # or annotated_<course_name>_<assignment_name>_<ver>_<handin>
  def download_filename(path, assignment_name)
    basename = File.basename path
    basename_parts = basename.split("_")
    basename_parts.insert(-3, assignment_name)
    download_name = basename_parts[-3..]
    download_name.join("_")
  end

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
    params.require(:user).permit(:first_name, :last_name, :school, :major, :administrator)
  end

  def set_gh_oauth_client
    gh_options = {
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      site: "https://github.com",
    }
    @gh_client = OAuth2::Client.new(Rails.configuration.x.github.client_id,
                                    Rails.configuration.x.github.client_secret,
                                    gh_options)
  end

  def set_user
    @user = User.find(params[:id])
    return unless @user.nil?

    flash[:error] = "User doesn't exist."
    redirect_to(user_path) && return
  end
end
