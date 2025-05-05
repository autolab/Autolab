module ScoreCalculation
  extend ActiveSupport::Concern

  # Instance methods for models that include this concern
  def update_score
    # Find the score for this submission and problem
    score = Score.find_or_initialize_by(
      submission_id: submission_id,
      problem_id: problem_id_for_score
    )
    
    # Set grader if not already set
    if score.grader_id.nil?
      instructor = submission.course_user_datum.course.course_user_data.find_by(instructor: true)
      score.grader_id = instructor ? instructor.id : submission.course_user_datum_id
    end
    
    # Set the score as released
    score.released = true
    
    # Calculate the total score from both annotations and rubric items
    total_score = calculate_total_score
    
    # Update the score
    score.update(score: total_score)
    
    # Update cached scores
    submission.invalidate_raw_score
    submission.update_latest_submission
    
    total_score
  end
  
  def calculate_total_score
    # Get problem ID depending on whether this is an annotation or rubric item assignment
    problem_id = problem_id_for_score
    
    # Calculate rubric item points
    rubric_item_points = submission.rubric_item_assignments
                                  .joins(:rubric_item)
                                  .where(assigned: true, rubric_items: { problem_id: problem_id })
                                  .sum('rubric_items.points')
    
    # Calculate annotation points
    annotation_points = 0
    
    if submission.group_key.empty?
      annotation_points = Annotation.where(submission_id: submission_id, problem_id: problem_id)
                                   .sum(:value)
    else
      # For group submissions, include annotations from all group submissions
      submissions = Submission.where(group_key: submission.group_key)
      submissions.each do |sub|
        annotation_points += Annotation.where(submission_id: sub.id, problem_id: problem_id)
                                      .sum(:value)
      end
    end
    
    # Add both rubric item points and annotation points for the final score
    rubric_item_points + annotation_points
  end
  
  private
  
  # Helper to get the correct problem_id depending on what type of object this is
  def problem_id_for_score
    if self.is_a?(Annotation)
      self.problem_id
    elsif self.is_a?(RubricItemAssignment)
      self.rubric_item.problem_id
    else
      raise "Unknown type for ScoreCalculation"
    end
  end
end
