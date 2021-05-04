# frozen_string_literal: true

module SubmissionHelper
  def plus_fix(f)
    f.positive? ? "+#{f}" : f.to_s
  end
end
