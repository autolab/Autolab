module SubmissionHelper
  def plus_fix(f)
    if f > 0
      sprintf("+%.2f", f.round(2))
    else
      sprintf("%.2f", f.round(2))
    end
  end

  def released(assessment, submission)
    released = true
    p_scores = submission.problems_to_scores
    assessment.problems.each_with_index do |p,i|
      p_score = p_scores[p.id]
      unless p_score&.released
        released = false
      end
    end
    released
  end
end
