require "AssessmentBase.rb"

module Hello
  include AssessmentBase

  def assessmentInitialize(course)
    super("hello",course)
    @problems = []
  end

end
