##
# This module, which is inherited by all modules, organizes how methods are overridden.
# I'm pretty sure this is obsolete.
#
module ModuleBase
  def updateModules
    @allModules = %w(Autograde Scoreboard Partners Svn)
    @modulesUsed = []
    assign = @assessment.name.gsub(/\./, "")
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/, "")).camelize

    for mod in @allModules do
      begin
        modUsed = eval("#{modName}.include?(#{mod})")
        @modulesUsed << mod if modUsed
      rescue Exception
        # do nothing
      end
    end
  end

  # This is easy to override, and no conflicts can occur
  def listAdmin
    super()
    updateModules

    autogradeListAdmin if @modulesUsed.include?("Autograde")

    scoreboardListAdmin if @modulesUsed.include?("Scoreboard")

    partnersListAdmin if @modulesUsed.include?("Partners")

    svnListAdmin if @modulesUsed.include?("Svn")
  end

  # We can only load *one* page. If other modules are created with custom
  # submission pages, this needs to be dealt with
  def loadHandinPage
    updateModules
    super()
  end

  # Validations can be combined if done in a descending order- make sure to
  # check for special module cases, like SVN!
  def validateHandin
    updateModules
    # Partners stand alone, they don't affect others
    if @modulesUsed.include?("Partners")
      return false unless partnersValidateHandin
    end

    # If we're validating for svn, we don't have a file to check
    if @modulesUsed.include?("Svn")
      return false unless svn_validate_handin
    else
      return false unless super()
    end
    true
  end

  # Saving a file produces a file, so it can only be done once.
  # If you need to combine two saves, write a new function
  def saveHandin
    if @modulesUsed.include?("Svn")
      return svn_save_handin
    else
      return super()
    end
  end
end
