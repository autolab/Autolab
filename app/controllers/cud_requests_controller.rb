class CudRequestsController < ApplicationController

  action_auth_no_course :create
  def create
    course_name = params[:course_name]
    @course = Course.find_by(name: course_name) if course_name
    
    if @course.requires_permission

      @newCudRequest = @course.cud_request.find_or_create_by(user_id: current_user.id)

      if @newCudRequest.save
        flash[:success] = "Success: You requested joined #{@course.display_name}"
        redirect_to(course_path(@course)) && return
      else
        flash[:error] = "Joining to request failed."
        redirect_to(course_path(@course)) && return
      end
    end
  end

  action_auth_no_course :destroy
  def destroy
    course_name = params[:course_name]
    @course = Course.find_by(name: course_name) if course_name
    @cudRequest = @course.cud_request.find(params[:id])

    if @cudRequest
      @cudRequest.delete
    end

    @cud = @course.course_user_data.find_by(user_id: current_user.id)

    if @cud && @cud.instructor?
      redirect_to(course_users_path(@course)) && return
    else
      redirect_to(course_path(@course)) && return
    end
  end

  action_auth_no_course :confirm
  def confirm
    course_name = params[:course_name]
    @course = Course.find_by(name: course_name) if course_name

    @cud = @course.course_user_data.find_by(user_id: current_user.id)

    if !@cud.instructor?
      redirect_to(course_path(@course)) && return
    end

    @cudRequest = @course.cud_request.find(params[:cud_request_id])
    @newCUD = @course.course_user_data.new
    @newCUD.user = @cudRequest.user

    if @newCUD.save
      @cudRequest.delete
    else
      flash[:error] = "There was a problem confirming this user."
    end

    if @cud && @cud.instructor?
      redirect_to(course_users_path(@course)) && return
    else
      redirect_to(course_path(@course)) && return
    end

  end

end
