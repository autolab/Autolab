class AssessmentUserDataController < ApplicationController
  
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_aud
  
  action_auth_level :edit, :instructor
  def edit
  end

  action_auth_level :update, :instructor
  def update
    if @aud.update(edit_aud_params) then
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
