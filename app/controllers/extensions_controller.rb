##
# Extensions can be for a finite amount of time or infinite.
#
class ExtensionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment

  # TODO
  action_auth_level :index, :instructor
  def index
    @extensions = @assessment.extensions.includes(:course_user_datum)
    @users = {}
    @course.course_user_data.each do |cud|
      @users[cud.full_name_with_email] = cud.id
    end
    @new_extension = @assessment.extensions.new
  end

  action_auth_level :create, :instructor
  def create
    # Do some verifications to make sure an instructor of one course is not
    # giving themselves an extension in another course!
    begin
      @course.course_user_data.find(params[:extension][:course_user_datum_id])
    rescue
      flash[:error] = "No student with id #{params[:extension][:course_user_datum_id]}
        was found for this course."
      redirect_to(action: :index) && return
    end
    ext = @assessment.extensions.create(extension_params)
    redirect_to(action: :index, errors: ext.errors.full_messages) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    extension = @assessment.extensions.find(params[:id])
    extension.destroy
    redirect_to(action: :index) && return
  end

private

  def extension_params
    params.require(:extension).permit(:course_user_datum_id, :days, :infinite,
                                      :commit, :course_id, :assessment_id)
  end
end
