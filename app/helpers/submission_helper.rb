module SubmissionHelper
  def plus_fix(f)
    f > 0 ? "+#{f}" : "#{f}"
  end
end
