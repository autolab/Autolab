class HomeController < ApplicationController

  skip_before_action :authenticate_user!, except: [ :publicSignUp ]
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements

  def developer_login
    if request.post?
      user = User.where(email: params[:email]).first
      if user
        sign_in :user, user
        redirect_to "/" and return
      else
        flash[:error] = "User with Email: '#{params[:email]}' doesn't exist"
        redirect_to "/home/developer_login" and return
      end
    end
  end

  # https://autolab.cs.cmu.edu/home/publicSignUp?id={#course_id}
  # where {#course_id} is the id of the public course a user wants to register
  def publicSignUp
    course_id = params[:id].to_i
    # for now, only check if this id is PUBLIC_COURSE_ID or ACM_COURSE_ID
    if (course_id != PUBLIC_COURSE_ID && course_id != ACM_COURSE_ID) then
      flash[:error] = "Public course doesn't exist. Please check your link again."
      redirect_to :controller => "home", :action => "index" and return
    end

    @course = Course.find(course_id)
    cud = CourseUserDatum.where(course: @course, user: current_user)
    if cud.nil? then
      # construct a new cud
      cud = @course.course_user_data.new(user: user)
    end
    # allows user to be an instructor for demo course only
    cud.instructor = params[:isInstructor] if course_id == PUBLIC_COURSE_ID
    if cud.save then
      flash[:success] = "You have successfully registered for " +
                          @course.display_name
      redirect_to :controller => "course", :course => @course.name,
          :action => "index" and return
    else
      flash[:error] = "An internal error occured. Please contact the " +
                    "Autolab Development team at the " +
                    "contact link below"
      redirect_to :controller => "home", :action => "index" and return
    end
  end

end
