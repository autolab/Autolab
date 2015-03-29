##
# This is mostly a reminder that SVN still doesn't work
#
module Svn
  # Override to specify how repository checkout should work
  # TODO: implement base versions for svn and git, these don't work
  def checkoutWork(_repo, targetDir)
    client = subversionType
    # if client == "svn" then
    #   `svn checkout #{repo} #{targetDir}`
    # elsif client == "git" then
    #   `git clone #{repo} #{targetDir}`
    if client == "test"
      Dir.mkdir(targetDir)
      testFile = File.join(targetDir, "test.txt")
      `echo "test" >> #{testFile}`
    else
      flash[:error] = "We do not support this subversion client.\n" \
        "You can override the checkout by implementing " \
        "checkoutWork(repo, targetDir)."
      return false
    end
    true
  end

protected

  # Override to change to a different subversion client.
  def subversionType
    "test"
  end
end
