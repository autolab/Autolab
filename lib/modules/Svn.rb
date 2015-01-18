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

  def svnLoadHandinPage()
    render(:file=>"lib/modules/views/checkoutSvn.html.erb", :layout=>true) and return
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
