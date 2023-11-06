require "AssessmentBase"

module Homework02
  include AssessmentBase

  def assessmentInitialize(course)
    super("homework0", course)
    @problems = []
  end
end
