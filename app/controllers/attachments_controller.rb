##
# Attachments can be either assessment or course-specific.
# This controller handles both types, setting @is_assessment to distinguish the two
#
class AttachmentsController < ApplicationController
  # inherited from ApplicationController
  # this will also set an @is_assessment variable based on the result of is_assessment?
  before_action :set_assessment, if: :assessment?
  before_action :set_attachment, except: %i[index new create]
  before_action :add_attachments_breadcrumb

  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

  action_auth_level :index, :instructor
  def index
    @attachments = @is_assessment ? @assessment.attachments : @course.attachments
  end

  action_auth_level :new, :instructor
  def new
    @attachment = Attachment.new
  end

  action_auth_level :create, :instructor
  def create
    @attachment = if @is_assessment
                    @course.attachments.new(assessment_id: @assessment.id)
                  else
                    @course.attachments.new
                  end

    update
  end

  action_auth_level :show, :student
  def show
    filename = Rails.root.join("attachments", @attachment.filename)
    unless File.exist?(filename)
      COURSE_LOGGER.log("Cannot find the file '#{@attachment.filename}' for"\
                        " attachment #{@attachment.name}")

      flash[:error] = "Error loading #{@attachment.name} from #{@attachment.filename}"
      redirect_to([@course, :attachments]) && return
    end
    # Set to application/octet-stream to force download
    send_file(filename, disposition: "inline",
                        type: "application/octet-stream", filename: @attachment.filename) && return
  end

  action_auth_level :edit, :instructor
  def edit; end

  action_auth_level :update, :instructor
  def update
    if @attachment.update(attachment_params)
      # is successful
      flash[:success] = "Attachment updated"
      redirect_to_attachment_list && return
    else
      # not successful, go back to edit page
      error_msg = "Attachment update failed:"
      if !@attachment.valid?
        @attachment.errors.full_messages.each do |msg|
          error_msg += "<br>#{msg}"
        end
      else
        error_msg += "<br>Unknown error"
      end
      flash[:error] = error_msg
      COURSE_LOGGER.log("Failed to update attachment: #{error_msg}")

      if @is_assessment
        redirect_to([:edit, @course, @assessment, @attachment]) && return
      end

      redirect_to([:edit, @course, @attachment]) && return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @attachment.destroy
    flash[:success] = "Attachment deleted"
    redirect_to_attachment_list && return
  end

private

  def assessment?
    @is_assessment = params.key?(:assessment_name)
  end

  def set_attachment
    @attachment = if @is_assessment
                    @course.attachments.find_by(assessment_id: @assessment.id, id: params[:id])
                  else
                    @course.attachments.find(params[:id])
                  end

    return unless @attachment.nil?

    COURSE_LOGGER.log("Cannot find attachment with id: #{params[:id]}")
    flash[:error] = "Could not find Attachment \# #{params[:id]}"
    redirect_to_attachment_list && return
  end

  def redirect_to_attachment_list
    if @is_assessment
      (redirect_to([@course, @assessment]) && return)
    end

    redirect_to([@course, :attachments]) && return
  end

  def add_attachments_breadcrumb
    @breadcrumbs << if @is_assessment
                      (view_context.link_to "Assessment Attachments",
                                            [@course, @assessment, :attachments])
                    else
                      (view_context.link_to "Course Attachments", [@course, :attachments])
                    end
  end

  def attachment_params
    params.require(:attachment).permit(:name, :file, :released, :mime_type)
  end
end
