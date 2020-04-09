##
# Extensions can be for a finite amount of time or infinite.
#
require 'base64'

class ExtensionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  # TODO
  action_auth_level :index, :instructor
  def index
    @extensions = @assessment.extensions.includes(:course_user_datum)
    @users = {}
    @usersEncoded = {}
    @course.course_user_data.each do |cud|
      @users[cud.full_name_with_email] = cud.id
      @usersEncoded[Base64.encode64(cud.full_name_with_email.strip).strip] = cud.id
    end
    @new_extension = @assessment.extensions.new
  end

  action_auth_level :create, :instructor
  def create
    # Do some verifications to make sure an instructor of one course is not
    # giving themselves an extension in another course!
    unless @course.course_user_data.find_by_id(params[:extension][:course_user_datum_id])
      flash[:error] = "No student with id #{params[:extension][:course_user_datum_id]}
        was found for this course."
      redirect_to(action: :index)
      return
    end
    ext = @assessment.extensions.create(extension_params)
    if !ext.errors.empty?
      flash[:error] = ext.errors.full_messages[0]
      redirect_to(action: :index) && return
    else
      flash[:success] = "Extension created successfully."
      redirect_to(action: :index) && return
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    extension = @assessment.extensions.find(params[:id])
    extension.destroy
    flash[:success] = "Extension deleted."
    redirect_to(action: :index) && return
  end

private

  def extension_params
    params.require(:extension).permit(:course_user_datum_id, :days, :infinite,
                                      :commit, :course_id, :assessment_id)
  end
end
