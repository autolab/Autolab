##
# Extensions can be for a finite amount of time or infinite.
#
require "base64"

class ExtensionsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_assessment_breadcrumb

  # TODO
  action_auth_level :index, :instructor
  def index
    @extensions = @assessment.extensions.includes(:course_user_datum)
    @users, @usersEncoded = @course.get_autocomplete_data
    @new_extension = @assessment.extensions.new
  end

  action_auth_level :create, :instructor
  def create
    unless params[:course_user_data].present?
      flash[:error] = "No users were specified!"
      redirect_to(action: :index) && return
    end
    cuds = params[:course_user_data].split(",")

    # Do some verifications to make sure an instructor of one course is not
    # giving themselves an extension in another course!
    cuds.each do |cud_id|
      cud = @course.course_user_data.find_by(id: cud_id)
      unless cud
        flash[:error] = "No user with id #{cud_id} was found for this course."
        redirect_to(action: :index) && return
      end
    end

    days = params[:extension][:days]
    infinite = params[:extension][:infinite]
    Extension.transaction do
      cuds.each do |cud_id|
        existing_ext = @assessment.extensions.find_by(course_user_datum_id: cud_id)
        if existing_ext
          existing_ext.days = days
          existing_ext.infinite = infinite
          existing_ext.save!
        else
          new_ext = @assessment.extensions.create(
            days:,
            infinite:,
            course_user_datum_id: cud_id,
            assessment_id: params[:extension][:assessment_id]
          )
          new_ext.save!
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
      redirect_to(action: :index) && return
    end

    emails = cuds.map { |cud_id| @course.course_user_data.find(cud_id).email }
    flash[:success] = "Extensions created for the following users: #{emails.join(', ')}."
    redirect_to(action: :index)
  end

  action_auth_level :destroy, :instructor
  def destroy
    extension = @assessment.extensions.find(params[:id])
    cud = extension.course_user_datum
    extension.destroy
    flash[:success] = "Extension deleted for user #{cud.email}."
    redirect_to(action: :index)
  end
end
