##
# Annotations are Submission and Problem specific.
# Currently, they are just text, but it would be nice if they could be used in
# score calculations in the future.
#
class Annotation < ApplicationRecord
  include ScoreCalculation
  
  belongs_to :submission
  belongs_to :problem
  belongs_to :rubric_item, optional: true

  validates :comment, :value, :filename, :submission_id, :problem_id, presence: true

  def as_text
    if value
      if problem
        "#{comment} (#{value}, #{problem.name})"
      else
        "#{comment} (#{value})"
      end
    elsif problem
      "#{comment} (#{problem.name})"
    else
      comment
    end
  end

  # Update all non-autograded scores with combined rubric items and annotations
  def update_non_autograded_score
    # Get score for submission
    score = Score.find_or_initialize_by(
      submission_id: submission_id, 
      problem_id: problem_id
    )

    # Associated problem was deleted
    return if score.problem_id && score.problem.nil?

    # Ensure that problem is non-autograded
    return if score.grader_id == 0

    # Update the score using the shared implementation
    update_score
  end
end
