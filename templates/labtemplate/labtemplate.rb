# frozen_string_literal: true

require "AssessmentBase"
require "modules/Autograde"

module Labtemplate
  include AssessmentBase
  include Autograde

  def assessmentInitialize(course)
    super("labtemplate", course)
    @problems = []
  end
end
