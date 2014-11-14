class ExtensionsController < ApplicationController
  
  # TODO
  action_auth_level :index, :instructor
  def index
    @title = "Manage Extensions"
    @assessment = @course.assessments.find(params[:assessment_id])
    if !@assessment then
      redirect_to course_path(@course) and return
    end
    @extensions = @assessment.extensions.includes(:course_user_datum)
    @users = {}
    for u in @course.course_user_data do
      @users[u.email] = u.id
    end
    @newExtension = @assessment.extensions.new
  end

  action_auth_level :create, :instructor
  def create
    if ! request.post? then
      flash[:error] = "Sorry, your request did not go through."
      redirect_to :controller=>"home", :action=>"error" and return
    end
    #Do some verifications to make sure an instructor of one course is not
    #giving themselves an extension in another course!
    if ! @course.assessments.find(params[:extension][:assessment_id]) then
      redirect_to :controller=>"course" ,:action=>"index" and return
    elsif ! @course.course_user_data.find(params[:extension][:course_user_datum_id]) then
      redirect_to :controller=>"course" ,:action=>"index" and return
    end
    ext = Extension.new(extension_params)
    ext.save
    redirect_to :action=>"index",
          :assessment_id=>ext.assessment.id,
          :errors=>ext.errors.full_messages
  end

  def extension_params
    params.require(:extension).permit(:course_user_datum_id, :days, :infinite, :assessment_id, :commit, :course_id, :assessment_id)
  end
  action_auth_level :destroy, :instructor
  def destroy
    extension = Extension.find(params[:id])
    if extension.assessment.course.id != @course.id then
      redirect_to :controller=>"course" ,:action=>"index" and return
    elsif extension.course_user_datum.course.id != @course.id then
      redirect_to :controller=>"course" ,:action=>"index" and return
    end
    extension.destroy()
    redirect_to :controller=>"extension",
          :action=>"index",
          :assessment=>extension.assessment.id
  end
end
