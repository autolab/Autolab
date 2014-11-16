module AssessmentSVN

  def adminSVN
=begin
    @sModule = UserModule.load("Svn.2",@assessment.id)
    if !@sModule then
      svnModuleInstall()
      @sModule = UserModule.load("Svn.2",@assessment.id)
    end
=end 

    @cuds = @course.course_user_data.joins(:user).order("users.email ASC")
=begin
    for cud in @cuds do
      repo = @sModule.get("repository", cud.id)
      if repo then
        cud["repository"] = repo
      end
    end
=end
    
    # Grab all assessments that also have the partners module
    @assessments = @course.assessments.where(has_svn: true)
  end
  
end
