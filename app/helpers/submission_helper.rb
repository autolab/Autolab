module SubmissionHelper
  def plus_fix(f)
    if f > 0
      sprintf("+%.2f", f.round(2))
    else
      sprintf("%.2f", f.round(2))
    end
  end

end
