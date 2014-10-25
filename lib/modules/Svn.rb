require "ModuleBase.rb"

module Svn
  include ModuleBase
  def svnModuleInstall
    UserModule.create(:name=>"Svn.2",:course_id=>@assessment.id)
    um = UserModule.load("Svn.2",@assessment.id)
    um.addColumn("repository",String)
  end

  # Override to specify how repository checkout should work
  # TODO: implement base versions for svn and git, these don't work
  def checkoutWork(repo, targetDir)
    client = subversionType()
    #if client == "svn" then
    #   `svn checkout #{repo} #{targetDir}`
    # elsif client == "git" then
    #   `git clone #{repo} #{targetDir}`
    if client == "test" then
      Dir.mkdir(targetDir)
      testFile = File.join(targetDir, "test.txt")
      `echo "test" >> #{testFile}`
    else
      flash[:error] = "We do not support this subversion client.\n" +
        "You can override the checkout by implementing " +
        "checkoutWork(repo, targetDir)."
      return false
    end
    return true
  end

  def svnListOptions
    @list["handin"] = "Checkout your work for credit"
    @list_title["handin"] = "Checkout your work for credit"
  end

  def svnLoadHandinPage()
    render(:file=>"lib/modules/views/checkoutSvn.html.erb", :layout=>true) and return
  end

  def adminSvn()
    if !(@cud.instructor? || @cud.user.administrator?) then
      flash[:error] = "You are not authorized to view this page"
      redirect_to :action=>"error",:controller=>"home" and return
    end
    @sModule = UserModule.load("Svn.2",@assessment.id)
    if !@sModule then
      svnModuleInstall()
      @sModule = UserModule.load("Svn.2",@assessment.id)
    end
    @cuds = @course.course_user_data.joins(:user).order("user.email ASC")
    for cud in @cuds do
      repo = @sModule.get("repository", cud.id)
      if repo then
        cud["repository"] = repo
      end
    end
    
    # Grab all assessments that also have the partners module
    assessments = @course.assessments
    @assessments = []
    for ass in assessments do
      if @assessment.id == ass.id then
        next
      end

      tempModule = UserModule.load("Svn.2", ass.id)
      if tempModule then
        @assessments << ass
      end
    end
    
    render(:file=>"lib/modules/views/adminSvn.html.erb", 
           :layout=>true) and return
  end

  def setRepository()
    if !(@cud.instructor? || @cud.user.administrator?) then
      flash[:error] = "You are not authorized to view this page"
      redirect_to :action=>"error",:controller=>"home" and return
    end
    @sModule = UserModule.load("Svn.2", @assessment.id)
    if !@sModule then
      svnModuleInstall()
      @sModule = UserModule.load("Svn.2", @assessment.id)
    end

    # We let admins overwrite repos, so no checks are required
    @sModule.put("repository", params[:id], params[:repository])
    redirect_to :action=>"adminSvn"
  end

  def importSvn
    if !(@cud.instructor? || @cud.user.administrator?) then
      flash[:error] = "You are not authorized to perform this action"
      redirect_to :action=>"error", :controller=>"home" and return
    end
    assessment = @course.assessments.find(params[:importfrom])
    oldModule = UserModule.load("Svn.2",assessment.id)
    if !oldModule
      flash[:error] = "The svn module was not used in that " +
        "assessment!"
      redirect_to :action=>"adminSvn" and return
    end

    @sModule = UserModule.load("Svn.2",@assessment.id)
    if !@sModule then
      svnModuleInstall()
      @sModule = UserModule.load("Svn.2", @assessment.id)
    end
    
    for cud in @course.course_user_data do
      # When importing, clear all current entries
      if @sModule.get("repository", cud.id) then
        @sModule.delete("repository", cud.id)
      end

      # And then add the new ones!
      if oldModule.get("repository", cud.id) then
        @sModule.put("repository", cud.id, oldModule.get("repository", cud.id))
      end
    end
    flash[:info] = "Repositories were imported successfully"
    redirect_to :action=>"adminSvn" and return
  end

  protected

  def svnValidateHandin()
    @sModule = UserModule.load("Svn.2",@assessment.id)
    if !@sModule then
      svnModuleInstall()
      @sModule = UserModule.load("Svn.2",@assessment.id)
    end
    
    repo = @sModule.get("repository", @cud.id)
    if repo.nil? then
      flash[:error] = "Your repository has not been registered- " +
        "please contact your course staff."
      return false
    end
    return true
  end

  def svnSaveHandin()
    @submission = Submission.create(:assessment_id => @assessment.id,
                                    :course_user_datum_id => @cud.id,
                                    :submitter_ip => request.remote_ip)
    
    # Checkout the svn directory and put it into a tar file
    repo = @sModule.get("repository", @cud.id)
    assDir = File.join(Rails.root, "courses", @course.name, @assessment.name, @assessment.handin_directory)
    svnDir = File.join(assDir, @cud.user.email + "_svn_checkout")
    svnTar = File.join(assDir, @cud.user.email + "_svn_checkout.tar.gz")
    if File.exists?(svnDir) then
      # To avoid conflicts, end this handin
      flash[:error] = "Another checkout is already in progress"
      return nil
    end
    if ! checkoutWork(repo, svnDir) then
      # Clean up svnDir
      `rm -r #{svnDir}`
      return nil
    end
    # Tar up the checked-out work, then clean up the directory
    `tar -cvf #{svnTar} #{svnDir} --exclude ".svn"`
    `rm -r #{svnDir}`
    if ! File.exists?(svnTar) then
      flash[:error] = "There was a problem with checking out your " +
        "work, please try again."
      return nil
    end
    sub = { }
    sub["tar"] = svnTar
    @submission.saveFile(sub)
    `rm #{svnTar}`
    return @submission
  end
  
  # Override to change to a different subversion client.
  def subversionType
    return "test"
  end
end 
