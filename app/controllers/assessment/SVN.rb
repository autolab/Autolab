module AssessmentSVN
  # action_auth_level :adminSVN, :instructor
  def adminSVN
    # Grab the CUDS.  ALL THE CUDS.
    @cuds = @course.course_user_data.includes(:user).order("users.email ASC")

    # Grab all assessments that also have SVN
    @assessments = @course.assessments.where(has_svn: true).where.not(id: @assessment.id)
  end

  # action_auth_level :setRepository, :instructor
  def setRepository
    aud = @assessment.aud_for params[:cud_id]
    aud.repository = params[:repository]
    aud.save!

    redirect_to(action: :adminSVN) && return
  end

  # action_auth_level :importSVN, :instructor
  def importSVN
    assessment = @course.assessments.find(params[:importfrom])
    unless assessment.has_svn
      flash[:error] = "SVN was not used in that assessment!"
      redirect_to(action: :adminSVN) && return
    end

    for cud in @course.course_user_data do
      oldRepo = assessment.aud_for(cud).repository
      if oldRepo
        aud = @assessment.aud_for(cud)
        aud.repository = oldRepo
        aud.save!
      end
    end

    flash[:info] = "Repositories were imported successfully"
    redirect_to(action: :adminSVN) && return
  end

protected

  def svnValidateHandin
    repo = @assessment.aud_for(@cud).repository
    if repo
      return true
    else
      flash[:error] = "Your repository has not been registered.  Please contact your course staff."
      return false
    end
  end

  def svnSaveHandin
    @submission = @assessment.submissions.new(course_user_datum: @cud,
                                              submitter_ip: request.remote_ip)

    # Checkout the svn directory and put it into a tar file
    repo = @assessment.aud_for(@cud).repository
    assDir = Rails.root("courses", @course.name, @assessment.name, @assessment.handin_directory)
    svnDir = File.join(assDir, @cud.user.email + "_svn_checkout")
    svnTar = File.join(assDir, @cud.user.email + "_svn_checkout.tar.gz")

    if File.exist?(svnDir)
      # To avoid conflicts, end this handin
      flash[:error] = "Another checkout is already in progress"
      return nil
    end

    unless checkoutWork(repo, svnDir)
      # Clean up svnDir
      `rm -r #{svnDir}`
      return nil
    end

    # Tar up the checked-out work, then clean up the directory
    `tar -cvf #{svnTar} #{svnDir} --exclude ".svn"`
    `rm -r #{svnDir}`
    unless File.exist?(svnTar)
      flash[:error] = "There was a problem with checking out your work, please try again."
      return nil
    end

    sub = {}
    sub["tar"] = svnTar
    @submission.save_file(sub) # this will also save the submission model if successful
    `rm #{svnTar}`

    @submission
  end
end
