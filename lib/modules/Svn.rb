module Svn
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

  protected
  
  # Override to change to a different subversion client.
  def subversionType
    return "test"
  end
end 
