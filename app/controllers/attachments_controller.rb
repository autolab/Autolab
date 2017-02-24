##
# Attachments can be either assessment or course-specific.
# This controller handles both types, setting @is_assessment to distinguish the two
#
class AttachmentsController < ApplicationController
  # inherited from ApplicationController
  # this will also set an @is_assessment variable based on the result of is_assessment?
  before_action :set_assessment, if: :assessment?
  before_action :set_attachment, except: [:index, :new, :create]
  before_action :add_attachments_breadcrumb

    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :index, :instructor
  def index
    @attachments = (@is_assessment) ? @assessment.attachments : @course.attachments
  end

  action_auth_level :new, :instructor
  def new
    @attachment = Attachment.new
  end

  action_auth_level :create, :instructor
  def create
    if @is_assessment
      @attachment = @course.attachments.new(assessment_id: @assessment.id)
    else
      @attachment = @course.attachments.new
    end

    update
  end

  action_auth_level :show, :student
  def show
    unless @attachment
      flash[:error] = "Could not find Attachment # #{params[:id]}"
      redirect_to([@course, :attachments]) && return
    end
    filename = File.join("attachments", @attachment.filename)
    unless File.exist?(filename)
      flash[:error] = "Error loading #{@attachment.name} from #{@attachment.filename}"
      redirect_to([@course, :attachments]) && return
    end
    send_file(filename, disposition: "inline",
                        type: @attachment.mime_type, filename: @attachment.filename) && return
  end

  action_auth_level :edit, :instructor
  def edit
  end

  action_auth_level :update, :instructor
  def update
    if @attachment.update(attachment_params)
      if @is_assessment
        redirect_to([@course, @assessment]) && return
      else
        redirect_to([@course, :attachments]) && return
      end
    else
      if @is_assessment
        redirect_to([:edit, @course, @assessment, @attachment]) && return
      else
        redirect_to([:edit, @course, @attachment]) && return
      end
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @attachment.destroy
    if @is_assessment
      redirect_to([@course, @assessment]) && return
    else
      redirect_to([@course, :attachments]) && return
    end
  end

private

  def assessment?
    @is_assessment = params.key?(:assessment_name)
  end

  def set_attachment
    if @is_assessment
      @attachment = @course.attachments.find_by!(assessment_id: @assessment.id, id: params[:id])
    else
      @attachment = @course.attachments.find(params[:id])
    end
  end

  def add_attachments_breadcrumb
    if @is_assessment
      @breadcrumbs << (view_context.link_to "Assessment Attachments",
                                            [@course, @assessment, :attachments])
    else
      @breadcrumbs << (view_context.link_to "Course Attachments", [@course, :attachments])
    end
  end

  def attachment_params
    params.require(:attachment).permit(:name, :file, :released, :mime_type)
  end
end
