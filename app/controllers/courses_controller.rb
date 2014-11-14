class CoursesController < ApplicationController
  # you need to be able to pick a course to be authorized for it
  skip_before_action :authorize_user_for_course, only: [ :index, :new, :create ]
  # if there's no course, there are no persistent announcements for that course
  skip_before_action :update_persistent_announcements, only: [ :index, :new, :create ]
  skip_before_action :authenticate_for_action
  
  def index
    courses_for_user = User.courses_for_user current_user

    if courses_for_user.any?
      @listing = categorize_courses_for_listing courses_for_user
    else
      redirect_to home_no_user_path and return
    end

    render layout: "home"
  end

  def new
    # check for permission
    if !current_user.administrator? then
      flash[:error] = "Permission denied."
      redirect_to root_path and return
    end
    @newCourse = Course.new
    @newCourse.late_penalty = Penalty.new
    @newCourse.version_penalty = Penalty.new
  end

  def create
    # check for permission
    if !current_user.administrator? then
      flash[:error] = "Permission denied."
      redirect_to root_path and return
    end
    
    @newCourse = Course.new(new_course_params)
    @newCourse.display_name = @newCourse.name
    
    # fill temporary values in other fields
    @newCourse.late_slack = 0
    @newCourse.grace_days = 0
    @newCourse.start_date = Time.now
    @newCourse.end_date = Time.now
    
    @newCourse.late_penalty = Penalty.new
    @newCourse.late_penalty.kind = "points"
    @newCourse.late_penalty.value = "0"
    
    @newCourse.version_penalty = Penalty.new
    @newCourse.version_penalty.kind = "points"
    @newCourse.version_penalty.value = "0"

    if @newCourse.save then
      instructor = User.where(email: params[:instructor_email]).first
      
      # create a new user as instructor if he didn't exist
      if (instructor.nil?)
        instructor = User.instructor_create(params[:instructor_email],
                                            @newCourse.name)
      end
      
      newCUD = @newCourse.course_user_data.new
      newCUD.user = instructor
      newCUD.instructor = true
      
      if newCUD.save then
        flash[:success] = "New Course #{@newCourse.name} successfully created!"
        redirect_to edit_course_path(@newCourse) and return
      else
        # roll back course creation
        @newCourse.destroy
        flash[:error] = "Can't create instructor for the course."
        render action: 'new' and return
      end
        
    else
      flash[:error] = "Course creation failed. Check all fields"
      render action: 'new' and return
    end
  end

  def show
    redirect_to course_assessments_url(@course)
  end

  action_auth_level :edit, :instructor
  def edit
    
  end

  action_auth_level :update, :instructor
  def update
    if @course.update(edit_course_params) then
      flash[:success] = "Success: Course info updated."
      redirect_to edit_course_path(@course)
    else
      flash[:error] = "Error: There were errors editing the course."
    end
  end

  # DELETE courses/:id/
  action_auth_level :destroy, :administrator
  def destroy
    if !current_user.administrator?
      flash[:error] = "Permission denied."
      redirect_to courses_path and return
    end
    
    course = Course.find(params[:id])
    if course.nil?
      flash[:error] = "Course doesn't exist."
      redirect_to courses_path and return
    end
    
    course.destroy
    flash[:success] = "Course destroyed."
    redirect_to courses_path and return
  end

# Non-RESTful Routes Below

  def report_bug
    if request.post?
      CourseMailer.bug_report(
        params[:title],
        params[:summary],
        current_user,
        @course
      ).deliver
    end
  end


  # Only instructor (and above) can use this feature
  # to look up user accounts and fill in cud fields
  action_auth_level :userLookup, :instructor
  def userLookup

    if params[:email].length == 0 then
      flash[:error] = "No email supplied for LDAP Lookup"
      render action: :new, layout: false and return
    end
    
    # make sure that user already exists in the database
    user = User.where(email: params[:email]).first
    
    if user.nil? then
      render json: nil and return
    end

    @user_data = { :first_name => user.first_name,
                   :last_name=> user.last_name, 
                   :email => user.email }

    return render json: @user_data

  end

private

  def new_course_params
    params.require(:newCourse).permit(:name, :semester)
  end

  def edit_course_params
    params.require(:editCourse).permit(:name, :semester, :late_slack, :grace_days, :display_name, :start_date, :end_date,
      :disabled, :exam_in_progress, :version_threshold, :gb_message,
      late_penalty_attributes: [:kind, :value],
      version_penalty_attributes: [:kind, :value])
  end
  
  def categorize_courses_for_listing(courses)
    listing = {}
    listing[:disabled] = []

    # temporal
    listing[:current] = []
    listing[:completed] = []
    listing[:upcoming] = []

    # categorize
    courses.each do |course|
      if course.disabled?
        listing[:disabled] << course
      else
        listing[course.temporal_status] << course
      end
    end

    listing
  end

end
