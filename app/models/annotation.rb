##
# Annotations are Submission and Problem specific.
# Currently, they are just text, but it would be nice if they could be used in
# score calculations in the future.
#
class Annotation < ApplicationRecord
  belongs_to :submission
  belongs_to :problem

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

  # Update all non-autograded scores with the following formula:
  # score_p = max_score_p + sum of annotations for problem
  def update_non_autograded_score
    # Get score for submission, or create one if it does not already exist
    # Previously, scores would be created when instructors add a score
    # and save on the gradebook
    score = Score.find_or_initialize_by_submission_id_and_problem_id(
      submission_id, problem_id
    )

    # Associated problem was deleted
    return if score.problem_id && score.problem.nil?

    # Ensure that problem is non-autograded
    return if score.grader_id == 0

    # If score was newly-created, we need to add a grader_id to score
    if score.grader.nil?
      score.grader_id = CourseUserDatum.find_by(user_id: User.find_by(email: submitted_by).id,
                                                course_id: submission.assessment.course_id).id
    end

    # Obtain sum of all annotations for this score
    if submission.group_key.empty?
      annotation_delta = Annotation
                         .where(submission_id:,
                                problem_id:)
                         .map(&:value).sum { |v| v.nil? ? 0 : v }
    else
      submissions = Submission.where(group_key: submission.group_key)
      annotation_delta = 0
      submissions.each do |submission|
        annotation_delta += submission.annotations.where(problem_id:)
                                      .map(&:value).sum { |v| v.nil? ? 0 : v }
      end
    end

    # Default score to 0 if problem.max_score is nil
    max_score = score.problem.max_score || 0

    # Check if positive grading is enabled for this assessment
    new_score = if submission.assessment.is_positive_grading
                  annotation_delta
                else
                  max_score + annotation_delta
                end

    # Update score
    if submission.group_key.empty?
      score.update!(score: new_score)
    else
      # Find all scores
      group_submissions = submission.group_associated_submissions
      scores = [score]
      group_submissions.each do |group_submission|
        group_score = Score
                      .find_or_initialize_by_submission_id_and_problem_id(
                        group_submission.id, problem_id
                      )
        group_score.grader_id = score.grader_id
        scores.append(group_score)
      end
      scores.each do |group_score|
        group_score.update!(score: new_score)
      end
    end
  end
end
