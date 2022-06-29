






require "AssessmentBase.rb"

module Hellocat
  include AssessmentBase

  def assessmentInitialize(course)
    super("hellocat",course)
    @problems = []
  end

end
