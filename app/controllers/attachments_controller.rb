class AttachmentsController < ApplicationController
  before_action :load_assessment

  action_auth_level :index, :instructor
  def index
    @attachments = @course.attachments
    if (@is_assessment) then
      @attachments = @assessment.attachments
    end
  end
  
  action_auth_level :new, :instructor
  def new
  end

  action_auth_level :create, :instructor
  def create
    @attachment = Attachment.new(course_id: @course.id, assessment_id: params[:assessment_id])
    if (@attachment.update(attachment_params)) then
      if (@is_assessment) then
        redirect_to course_assessment_attachments_path(@course, @attachment.assessment) and return
      else
        redirect_to course_attachments_path(@course) and return
      end
    end
    redirect_to new_course_attachment_path(@course) and return
  end

  action_auth_level :show, :student
  def show
    @attachment = @course.attachments.find(params[:id])
    if !@attachment then
      flash[:error] = "Could not find Attachment # #{params[:id]}"
      redirect_to :controller=>"home",:action=>"error" and return
    end
    filename= File.join("attachments",@attachment.filename)
    if ! File.exists?(filename) then
      flash[:error] = "Error loading #{@attachment.name} from #{@attachment.filename}"
      redirect_to :controller=>"home",:action=>"error" and return
    end
    send_file(filename,:disposition=>'inline',:type=>@attachment.mime_type,:filename=>@attachment.filename) and return
  end

  action_auth_level :edit, :instructor
  def edit
    if @is_assessment then
      @attachment = @course.attachments.where(assessment_id: params[:assessment_id], id: params[:id]).first
    else
      @attachment = @course.attachments.where(id: params[:id]).first
    end
  end

  action_auth_level :update, :instructor
  def update
    if @is_assessment then
      @attachment = @course.attachments.where(assessment_id: params[:assessment_id]).first
      if (@attachment && @attachment.update(attachment_params)) then
        redirect_to course_assessment_attachments_path(@course, @attachment.assessment) and return
      else
        redirect_to [:edit, @course, @attachment.assessment, @attachment] and return
      end
    else
      @attachment = @course.attachments.where(id:params[:id]).first
      @attachment.update(attachment_params)
      redirect_to course_attachments_path(@course) and return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @attachment = Attachment.find(params[:id])
    @attachment.destroy()
    if @is_assessment then
      redirect_to course_assessment_attachments_path(@course, params[:assessment_id]) and return
    else
      redirect_to course_attachments_path(@course) and return
    end
  end

private

  def load_assessment
    @is_assessment = params.has_key?(:assessment_id)
    if @is_assessment then
      @assessment = @course.assessments.find(params[:assessment_id])
      if @cud.student? && !@assessment.released? then
        redirect_to [@course, :assessments] and return false
      end
    end
  end

  def attachment_params
    params.require(:attachment).permit(:name, :file, :released, :mime_type)
  end

end
