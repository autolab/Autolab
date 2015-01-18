module AssessmentSVN

  # action_auth_level :instructor
  def adminSVN
    @cuds = @course.course_user_data.includes(:user).select(:email).order("users.email ASC")
    
    # Grab all assessments that also have the SVN module
    @assessments = @course.assessments.where(has_svn: true)
  end

  # action_auth_level :instructor
  def setRepository
    cud = @course.course_user_data.find(params[:cud_id])
    aud = @assessment.aud_for cud
    aud.repository = params[:repository]
    aud.save!
    
    redirect_to action: :adminSVN and return
  end

  # action_auth_level :instructor
  def importSVN
    assessment = @course.assessments.find(params[:importfrom])
    
    for cud in @course.course_user_data do
      oldRepo = assessment.aud_for(cud).repository
      if oldRepo then
        aud = @assessment.aud_for(cud)
        aud.repository = oldRepo
        aud.save!
      end
    end

    flash[:info] = "Repositories were imported successfully"
    redirect_to action: :adminSVN and return
  end
 
end
