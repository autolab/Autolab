# frozen_string_literal: true

require "AssessmentBase"

module Hello
  include AssessmentBase

  def assessmentInitialize(course)
    super("hello", course)
    @problems = []
  end
end
