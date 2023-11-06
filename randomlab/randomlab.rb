require "AssessmentBase.rb"

module Randomlab
  include AssessmentBase

  def assessmentInitialize(course)
    super("randomlab",course)
    @problems = []
  end
end
