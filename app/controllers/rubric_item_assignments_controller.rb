class RubricItemAssignmentsController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_rubric_item
  
  # POST /courses/:course_id/assessments/:assessment_id/submissions/:submission_id/rubric_items/:rubric_item_id/toggle
  action_auth_level :toggle, :course_assistant
  def toggle
    # Find or create the rubric item assignment
    assignment = RubricItemAssignment.find_or_initialize_by(
      submission_id: @submission.id,
      rubric_item_id: @rubric_item.id
    )
    
    # Toggle the assigned status
    assignment.assigned = !assignment.assigned
    
    # Save the assignment status
    if assignment.save
      # Find or initialize the score for this submission and problem
      score = Score.find_or_initialize_by(
        submission_id: @submission.id,
        problem_id: @rubric_item.problem_id
      )
      
      # Set grader if not already set
      if score.new_record? || score.grader_id.nil?
        score.grader_id = @cud.id
      end
      
      # Calculate the sum of all assigned rubric items for this problem
      assigned_points = @submission.rubric_item_assignments
                                 .joins(:rubric_item)
                                 .where(assigned: true, rubric_items: { problem_id: @rubric_item.problem_id })
                                 .sum('rubric_items.points')
      
      # Update the score
      score.score = assigned_points
      score.save
      
      flash[:success] = assignment.assigned ? "Rubric item assigned" : "Rubric item unassigned"
      
      # Redirect back to the submission view
      redirect_to view_course_assessment_submission_path(@course, @assessment, @submission, params[:header_position])
    else
      flash[:error] = "Failed to update rubric item assignment"
      redirect_to view_course_assessment_submission_path(@course, @assessment, @submission, params[:header_position])
    end
  end
  
  private
  
  def set_assessment
    @assessment = @course.assessments.find_by(name: params[:assessment_id])
  end
  
  def set_submission
    @submission = @assessment.submissions.find(params[:submission_id])
  end
  
  def set_rubric_item
    @rubric_item = RubricItem.find(params[:rubric_item_id])
  end
end
