class AssessmentUserDataController < ApplicationController
  
  action_auth_level :edit, :instructor
  def edit
    @aud = AssessmentUserDatum.find params[:id]
  end

  def update
    @aud = AssessmentUserDatum.find params[:id]

    if (@aud.update_attributes params[:assessment_user_datum])
      flash[:notice] = "Grade type updated!"
      redirect_to :action => :show
    else
      flash[:error] = "Error updating grade type!"
      render :edit
    end
  end

  def show
    redirect_to :action => :edit
  end

end
