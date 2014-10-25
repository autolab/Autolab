require "AssessmentBase.rb"
##MODULES_REQUIRE##

module ##NAME_CAMEL##
  include AssessmentBase
##MODULES_INCLUDE##

  def assessmentInitialize(course)
    super("##NAME_LOWER##",course)
    @problems = []
  end

end
