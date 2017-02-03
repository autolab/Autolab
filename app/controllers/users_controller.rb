class UsersController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

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
        if cud.instructor?
          user_cud =
            cud.course.course_user_data.where(user: user).first
          user_cuds << user_cud unless user_cud.nil?
        end
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

    temp_pass = Devise.friendly_token[0, 20]    # generate a random token
    @user.password = temp_pass
    @user.password_confirmation = temp_pass
    @user.skip_confirmation!

    if @user.save
      @user.send_reset_password_instructions
      flash[:success] = "User creation success"
      redirect_to(users_path) && return
    else
      flash[:error] = "User creation failed"
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
    else
      # current user can only edit himself if he's neither role
      if user != current_user
        flash[:error] = "Permission denied"
        redirect_to(users_path) && return
      else
        @user = current_user
      end
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
    else
      # current user can only edit himself if he's neither role
      if user != current_user
        flash[:error] = "Permission denied"
        redirect_to(users_path) && return
      else
        @user = current_user
      end
    end

    if user.update(current_user.administrator? ?
                    admin_user_params : user_params)
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

    # TODO Need to cleanup user resources here

    user.destroy
    flash[:success] = "User destroyed."
    redirect_to(users_path) && return
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
end
