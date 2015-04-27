require "AssessmentBase.rb"

module ##NAME_CAMEL##
  include AssessmentBase

  def assessmentInitialize(course)
    super("##NAME_LOWER##",course)
    @problems = []
  end

end
