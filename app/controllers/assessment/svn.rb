##
# This module defines functions for using SVN in an Assessment.
# We may want this to work with generic VCS some day
#
module AssessmentSVN
  # action_auth_level :admin_svn, :instructor
  def admin_svn
    # Grab the CUDS.  ALL THE CUDS.
    @cuds = @course.course_user_data.includes(:user).order("users.email ASC")

    # Grab all assessments that also have SVN
    @assessments = @course.assessments.where(has_svn: true).where.not(id: @assessment.id)
  end

  # action_auth_level :set_repo, :instructor
  def set_repo
    aud = @assessment.aud_for params[:cud_id]
    aud.repository = params[:repository]
    aud.save!

    redirect_to(action: :admin_svn) && return
  end

  # action_auth_level :import_svn, :instructor
  def import_svn
    assessment = @course.assessments.find(params[:importfrom])
    unless assessment.has_svn
      flash[:error] = "SVN was not used in that assessment!"
      redirect_to(action: :admin_svn) && return
    end

    @course.course_user_data.each do |cud|
      old_repo = assessment.aud_for(cud).repository
      next unless old_repo
      aud = @assessment.aud_for(cud)
      aud.repository = old_repo
      aud.save!
    end

    flash[:notice] = "Repositories were imported successfully"
    redirect_to(action: :admin_svn) && return
  end

protected

  def svn_validate_handin
    repo = @assessment.aud_for(@cud).repository
    return true if repo
    flash[:error] = "Your repository has not been registered.  Please contact your course staff."
    false
  end

  def svn_save_handin
    @submission = @assessment.submissions.new(course_user_datum: @cud,
                                              submitter_ip: request.remote_ip)

    # Checkout the svn directory and put it into a tar file
    repo = @assessment.aud_for(@cud).repository
    ass_dir = Rails.root("courses", @course.name, @assessment.name, @assessment.handin_directory)
    svn_dir = File.join(ass_dir, @cud.user.email + "_svn_checkout")
    svn_tar = File.join(ass_dir, @cud.user.email + "_svn_checkout.tar.gz")

    if File.exist?(svn_dir)
      # To avoid conflicts, end this handin
      flash[:error] = "Another checkout is already in progress"
      return nil
    end

    unless checkoutWork(repo, svn_dir)
      # Clean up svn_dir
      `rm -r #{svn_dir}`
      return nil
    end

    # Tar up the checked-out work, then clean up the directory
    `tar -cvf #{svn_tar} #{svn_dir} --exclude ".svn"`
    `rm -r #{svn_dir}`
    unless File.exist?(svn_tar)
      flash[:error] = "There was a problem with checking out your work, please try again."
      return nil
    end

    sub = {}
    sub["tar"] = svn_tar
    @submission.save_file(sub) # this will also save the submission model if successful
    `rm #{svn_tar}`

    @submission
  end
end
