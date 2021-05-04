# frozen_string_literal: true

require "AssessmentBase"

module Hellocat
  include AssessmentBase

  def assessmentInitialize(course)
    super("hellocat", course)
    @problems = []
  end
end
