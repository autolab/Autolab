##
# The Home Controller houses (ha) any action that's available to the general public.
#
class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements

  def developer_login
    return unless request.post?

    user = User.find_by(email: params[:email])
    if user
      sign_in :user, user
      redirect_to("/") && return
    else
      flash[:error] = "User with Email: '#{params[:email]}' doesn't exist"
      redirect_to("/home/developer_login") && return
    end
  end

  def join_course
    return unless request.post?

    access_code = params[:access_code]
    unless access_code.match(/\A[A-Z0-9]{6}\z/)
      flash[:error] = "Invalid access code format"
      redirect_to home_join_course_path && return
    end

    course = Course.find_by(access_code:)
    if course.nil?
      flash[:error] = "Invalid access code"
      redirect_to home_join_course_path && return
    end

    cud = course.course_user_data.find_by(user_id: current_user.id)

    if cud.nil?
      cud = course.course_user_data.new
      cud.user = current_user
      cud.instructor = false
      cud.course_assistant = false
      unless cud.save
        flash[:error] = "An error occurred while joining the course"
        redirect_to home_join_course_path && return
      end
      # else, no point setting a flash because they will be redirected
      # to set their nickname
    else
      flash[:success] = "You are already enrolled in this course"
    end

    redirect_to course_path(course)
  end

  def contact
    # --- empty ---
    # This route just renders the home#contact page, nothing special
  end

  def error_404; end

  def error_500; end
end
