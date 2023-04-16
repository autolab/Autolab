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
    if params[:attachment][:file].size > 1.gigabyte
      flash[:error] = "Attachment file size must be less than 1 GB"
      redirect_to_create_attachment && return
    end

    @attachment = if @is_assessment
                    @course.attachments.new(assessment_id: @assessment.id)
                  else
                    @course.attachments.new
                  end

    if @attachment.update(attachment_params)
      flash[:success] = "Attachment created"
      redirect_to_attachment_list
    else
      error_msg = "Attachment create failed:"
      if !@attachment.valid?
        @attachment.errors.full_messages.each do |msg|
          error_msg += "<br>#{msg}"
        end
      else
        error_msg += "<br>Unknown error"
      end
      flash[:error] = error_msg
      flash[:html_safe] = true
      COURSE_LOGGER.log("Failed to create attachment: #{error_msg}")
      redirect_to_create_attachment
    end
  end

  action_auth_level :show, :student
  def show
    if @cud.instructor? || @attachment.released?
      begin
        attached_file = @attachment.attachment_file
        if attached_file.attached?
          send_data attached_file.download, filename: @attachment.filename,
                                            type: @attachment.mime_type
          return
        end

        old_attachment_path = Rails.root.join("attachments", @attachment.filename)
        if File.exist?(old_attachment_path)
          send_file old_attachment_path, filename: @attachment.filename, type: @attachment.mime_type
        else
          COURSE_LOGGER.log("No file attached to attachment '#{@attachment.name}'")
          flash[:error] = "No file attached to attachment '#{@attachment.name}'"
          redirect_to([@course, :attachments])
        end
        return
      rescue StandardError
        COURSE_LOGGER.log("Error viewing attachment '#{@attachment.name}'")
        flash[:error] = "Error viewing attachment '#{@attachment.name}'"
        redirect_to([@course, @assessment]) && return
      end
    end

    flash[:error] = "You are unauthorized to view this attachment"
    redirect_to([@course, @assessment])
  end

  action_auth_level :edit, :instructor
  def edit; end

  action_auth_level :update, :instructor
  def update
    if @attachment.update(attachment_params)
      flash[:success] = "Attachment updated"
      redirect_to_attachment_list
    else
      error_msg = "Attachment update failed:"
      if !@attachment.valid?
        @attachment.errors.full_messages.each do |msg|
          error_msg += "<br>#{msg}"
        end
      else
        error_msg += "<br>Unknown error"
      end
      flash[:error] = error_msg
      flash[:html_safe] = true
      COURSE_LOGGER.log("Failed to update attachment: #{error_msg}")
      redirect_to_edit_attachment
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @attachment.destroy
    flash[:success] = "Attachment deleted"
    redirect_to_attachment_list
  end

private

  def assessment?
    @is_assessment = params.key?(:assessment_name)
  end

  def set_attachment
    @attachment = if @is_assessment
                    @course.attachments.find_by(assessment_id: @assessment.id, id: params[:id])
                  else
                    @course.attachments.find_by(id: params[:id])
                  end

    return unless @attachment.nil?

    COURSE_LOGGER.log("Cannot find attachment with id: #{params[:id]}")
    flash[:error] = "Could not find Attachment \##{params[:id]}"
    redirect_to_attachment_list
  end

  def redirect_to_create_attachment
    if @is_assessment
      redirect_to new_course_assessment_attachment_path(@course, @assessment)
    else
      redirect_to new_course_attachment_path(@course)
    end
  end

  def redirect_to_edit_attachment
    if @is_assessment
      redirect_to edit_course_assessment_attachment_path(@course, @assessment, @attachment)
    else
      redirect_to edit_course_attachment_path(@course, @attachment)
    end
  end

  def redirect_to_attachment_list
    if @is_assessment
      redirect_to course_assessment_path(@course, @assessment)
    else
      redirect_to course_path(@course)
    end
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
