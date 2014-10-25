class AccountController < ApplicationController
  
  action_auth_level :index, :student
  def index
    @requestedCud = @cud
    render :action=>:user
  end

  action_auth_level :user, :instructor
  def user
    @requestedUser = @cud.course.course_user_data.find(params[:id])
  end 

  action_auth_level :edit, :student
  def edit
    @editCUD = @course.course_user_data.find(params[:id])
    if @editCUD == nil then
      redirect_to :action=>"index" and return
    end 

    if (@editCUD.id != @cud.id) and (!@cud.instructor?) then
      redirect_to :action=>"index" and return
    end
 
    if not request.patch? 
      # page needs a dummy score adjustment to render
      @editCUD.tweak ||= Tweak.new 
    end

    if request.patch? then
      # ensure presence of nickname
      # isn't a User model validation since users can start off without nicknames
      # application_controller's authenticate_user redirects here if nickname isn't set
      if @cud.student? and params[:user][:nickname].blank?
        @editCUD.errors.add :nickname, "must be chosen"
        return
      end

      # won't have tweak attributes if student is editing
      tweak_attrs = params[:user][:tweak_attributes]
      if tweak_attrs && tweak_attrs[:value].blank?
        params[:user][:tweak_attributes][:_destroy] = true
      end

      # The protected fields can only be modified by instructors, 
      # we do them seperately
      if @cud.instructor? then
        @editCUD.school = params[:cud][:school]
        @editCUD.major = params[:cud][:major]
        @editCUD.year = params[:cud][:year]
        @editCUD.lecture = params[:cud][:lecture]
        @editCUD.section = params[:cud][:section]
        @editCUD.dropped = params[:cud][:dropped]
        @editCUD.instructor = params[:cud][:instructor]
        @editCUD.course_assistant = params[:cud][:course_assistant]
      end

      if @cud.user.administrator? then
        @editCUD.user.administrator = params[:user][:administrator]
      end

      # When we're finished editing, go back to the user table
      if @editCUD.update_attributes(params[:cud]) and
         @editCUD.user.update_attributes(params[:user]) then
        flash[:success] = "Success: Updated user #{@editCUD.user.email}"
        if @cud.user.administrator?
          redirect_to :controller=>"admin", :action=>"users" and return
        else
          redirect_to :action => "index" and return
        end
      end
    end 
  end

  action_auth_level :update, :student
  def update

  end

  action_auth_level :destroy, :instructor
  def destroy
    @destroyUser = @course.course_user_data.find(params[:id])
    if request.post? then 
      if params[:yes1] and params[:yes2] and params[:yes3] then
        @destroyUser.destroy() #awwww!!!
        redirect_to :controller=>"admin",:action=>"users" and return
      end
    end
  end

end
