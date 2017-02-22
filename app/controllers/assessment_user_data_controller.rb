##
# AssessmentUserData are joins between Assessments and CourseUserData.
# This basically lets you update grade types for a student for an assessment.
#
class AssessmentUserDataController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_aud
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :edit, :instructor
  def edit
    @breadcrumbs << (view_context.link_to "Gradesheet", [:viewGradesheet, @course, @assessment])
  end

  action_auth_level :update, :instructor
  def update
    if @aud.update(edit_aud_params)
      flash[:notice] = "Grade type updated!"
    else
      flash[:error] = "Error updating grade type!"
    end
    redirect_to action: :edit
  end

private

  def set_aud
    @aud = @assessment.assessment_user_data.find(params[:id])
  end

  def edit_aud_params
    params.require(:assessment_user_datum).permit(:grade_type)
  end
end
