module SubmissionHelper
  def plus_fix(f)
    if f > 0
      sprintf("+%.1f", f)
    else
      sprintf("%.1f", f)
    end
  end
end
