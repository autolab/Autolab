# This module, which is inherited by all modules, organizes how
# methods are overridden.

module ModuleBase
  def updateModules
    @allModules = %w(Autograde Scoreboard Partners Svn)
    @modulesUsed = []
    assign = @assessment.name.gsub(/\./, "")
    modName = (assign + (@course.name).gsub(/[^A-Za-z0-9]/, "")).camelize

    for mod in @allModules do
      begin
        modUsed = eval("#{modName}.include?(#{mod})")
        if modUsed
          @modulesUsed << mod
        end
      rescue Exception
        # do nothing
      end
    end
  end

  # This is easy to override, and no conflicts can occur
  def listAdmin
    super()
    updateModules

    if @modulesUsed.include?("Autograde")
      autogradeListAdmin
    end

    if @modulesUsed.include?("Scoreboard")
      scoreboardListAdmin
    end

    if @modulesUsed.include?("Partners")
      partnersListAdmin
    end

    if @modulesUsed.include?("Svn")
      svnListAdmin
    end
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
      unless partnersValidateHandin
        return false
      end
    end

    # If we're validating for svn, we don't have a file to check
    if @modulesUsed.include?("Svn")
      unless svnValidateHandin
        return false
      end
    else
      unless super()
        return false
      end
    end
    true
  end

  # Saving a file produces a file, so it can only be done once.
  # If you need to combine two saves, write a new function
  def saveHandin
    if @modulesUsed.include?("Svn")
      return svnSaveHandin
    else
      return super()
    end
  end
end
