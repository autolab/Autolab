class AttachmentsController < ApplicationController
  # inherited from ApplicationController
  # this will also set an @is_assessment variable based on the result of is_assessment?
  before_action :set_assessment, if: :is_assessment?
  before_action :add_attachments_breadcrumb

  action_auth_level :index, :instructor
  def index
    @attachments = @course.attachments
    if @is_assessment
      @attachments = @assessment.attachments
    end
  end

  action_auth_level :new, :instructor
  def new
  end

  action_auth_level :create, :instructor
  def create
    @attachment = Attachment.new(course_id: @course.id, assessment_id: params[:assessment_id])
    if @attachment.update(attachment_params)
      if @is_assessment
        redirect_to(course_assessment_attachments_path(@course, @attachment.assessment)) && return
      else
        redirect_to(course_attachments_path(@course)) && return
      end
    end
    redirect_to(new_course_attachment_path(@course)) && return
  end

  action_auth_level :show, :student
  def show
    @attachment = @course.attachments.find(params[:id])
    unless @attachment
      flash[:error] = "Could not find Attachment # #{params[:id]}"
      redirect_to([@course, :attachments]) && return
    end
    filename = File.join("attachments", @attachment.filename)
    unless File.exist?(filename)
      flash[:error] = "Error loading #{@attachment.name} from #{@attachment.filename}"
      redirect_to([@course, :attachments]) && return
    end
    send_file(filename, disposition: "inline", type: @attachment.mime_type, filename: @attachment.filename) && return
  end

  action_auth_level :edit, :instructor
  def edit
    if @is_assessment
      @attachment = @course.attachments.where(assessment_id: params[:assessment_id], id: params[:id]).first
    else
      @attachment = @course.attachments.where(id: params[:id]).first
    end
  end

  action_auth_level :update, :instructor
  def update
    if @is_assessment
      @attachment = @course.attachments.where(assessment_id: params[:assessment_id]).first
      if @attachment && @attachment.update(attachment_params)
        redirect_to(course_assessment_attachments_path(@course, @attachment.assessment)) && return
      else
        redirect_to([:edit, @course, @attachment.assessment, @attachment]) && return
      end
    else
      @attachment = @course.attachments.where(id: params[:id]).first
      @attachment.update(attachment_params)
      redirect_to(course_attachments_path(@course)) && return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @attachment = Attachment.find(params[:id])
    @attachment.destroy
    if @is_assessment
      redirect_to(course_assessment_attachments_path(@course, params[:assessment_id])) && return
    else
      redirect_to(course_attachments_path(@course)) && return
    end
  end

private

  def is_assessment?
    @is_assessment = params.key?(:assessment_id)
  end

  def add_attachments_breadcrumb
    if @is_assessment
      @breadcrumbs << (view_context.link_to "Assessment Attachments", [@course, @assessment, :attachments])
    else
      @breadcrumbs << (view_context.link_to "Course Attachments", [@course, :attachments])
    end
  end

  def attachment_params
    params.require(:attachment).permit(:name, :file, :released, :mime_type)
  end
end
