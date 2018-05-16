require "AssessmentBase.rb"

module Lab01
  include AssessmentBase

  def assessmentInitialize(course)
    super("lab01",course)
    @problems = []
  end

end
