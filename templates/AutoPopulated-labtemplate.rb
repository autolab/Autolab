require "AssessmentBase.rb"
require "modules/Autograde.rb"

module LabtemplateAutoPopulated
  include AssessmentBase
  include Autograde

  def assessmentInitialize(course)
    super("labtemplate", course)
    @problems = []
  end
end
