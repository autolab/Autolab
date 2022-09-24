##
# Extensions can be for a finite amount of time or infinite.
#
require "base64"

class ExtensionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

  # TODO
  action_auth_level :index, :instructor
  def index
    @extensions = @assessment.extensions.includes(:course_user_datum)
    @users, @usersEncoded = @course.get_autocomplete_data
    @new_extension = @assessment.extensions.new
  end

  action_auth_level :create, :instructor
  def create
    # Do some verifications to make sure an instructor of one course is not
    # giving themselves an extension in another course!
    cud_id = params[:extension][:course_user_datum_id]
    unless cud_id.present?
      flash[:error] = "No student was specified!"
      redirect_to(action: :index) && return
    end

    cud = @course.course_user_data.find(cud_id)
    unless cud
      flash[:error] = "No student with id #{cud_id} was found for this course."
      redirect_to(action: :index) && return
    end

    # Check for existing extension, and if so, update
    existing_ext = @assessment.extensions.find_by(course_user_datum_id: cud_id)
    if existing_ext
      existing_ext.days = params[:extension][:days]
      existing_ext.infinite = params[:extension][:infinite]
      existing_ext.save
      if !existing_ext.errors.empty?
        flash[:error] = existing_ext.errors.full_messages[0]
      else
        flash[:success] = "Extension updated successfully for user #{cud.email}."
      end
      redirect_to(action: :index) && return
    end

    # Create new extension instead
    ext = @assessment.extensions.create(extension_params)
    if !ext.errors.empty?
      flash[:error] = ext.errors.full_messages[0]
    else
      flash[:success] = "Extension created successfully for user #{cud.email}."
    end
    redirect_to(action: :index) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    extension = @assessment.extensions.find(params[:id])
    cud = extension.course_user_datum
    extension.destroy
    flash[:success] = "Extension deleted for user #{cud.email}."
    redirect_to(action: :index) && return
  end

private

  def extension_params
    params.require(:extension).permit(:course_user_datum_id, :days, :infinite,
                                      :commit, :course_id, :assessment_id)
  end
end
