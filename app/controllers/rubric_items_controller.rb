class RubricItemsController < ApplicationController
  before_action :set_assessment
  before_action :set_problem, except: [:toggle]
  before_action :set_rubric_item, only: [:edit, :update, :destroy, :toggle]
  before_action :set_submission, only: [:toggle]
  before_action :set_problem_from_rubric_item, only: [:toggle]

  action_auth_level :new, :instructor
  def new
    @rubric_item = @problem.rubric_items.new
  end

  action_auth_level :create, :instructor
  def create
    @rubric_item = @problem.rubric_items.new(rubric_item_params)
    @rubric_item.order = @problem.rubric_items.count

    if @rubric_item.save
      flash[:success] = "Rubric item created successfully"
      redirect_to edit_course_assessment_problem_path(@course, @assessment, @problem)
    else
      flash[:error] = "Error creating rubric item"
      @rubric_item.errors.full_messages.each do |msg|
        flash[:error] += "<br>#{msg}"
      end
      flash[:html_safe] = true
      render :new
    end
  end

  action_auth_level :edit, :instructor
  def edit; end

  action_auth_level :update, :instructor
  def update
    if @rubric_item.update(rubric_item_params)
      flash[:success] = "Rubric item updated successfully"
      redirect_to edit_course_assessment_problem_path(@course, @assessment, @problem)
    else
      flash[:error] = "Error updating rubric item"
      @rubric_item.errors.full_messages.each do |msg|
        flash[:error] += "<br>#{msg}"
      end
      flash[:html_safe] = true
      render :edit
    end
  end

  action_auth_level :destroy, :instructor
  def destroy
    @rubric_item.destroy
    flash[:success] = "Rubric item deleted successfully"
    redirect_to edit_course_assessment_problem_path(@course, @assessment, @problem)
  end

  action_auth_level :toggle, :course_assistant
  def toggle
    # Store previous state for better feedback
    was_assigned = RubricItemAssignment.find_by(
      submission_id: @submission.id,
      rubric_item_id: @rubric_item.id
    )&.assigned || false

    # Find or create the rubric item assignment
    assignment = RubricItemAssignment.find_or_initialize_by(
      submission_id: @submission.id,
      rubric_item_id: @rubric_item.id
    )

    # Toggle the assigned status
    assignment.assigned = !assignment.assigned

    # Save the assignment status and get the final score
    if assignment.save
      # Get the updated score after the save (which triggers recalculation)
      score = Score.find_by(submission_id: @submission.id, problem_id: @rubric_item.problem_id)
      score&.score || 0
      @problem.max_score || 0

      # Points change message
      point_change = was_assigned ? -@rubric_item.points : @rubric_item.points
      point_change >= 0 ? "+#{point_change}" : point_change.to_s

    else
      flash[:error] = "Failed to update rubric item assignment"
    end

    # Redirect with a cache-busting parameter to ensure fresh data is loaded
    redirect_to view_course_assessment_submission_path(
      @course,
      @assessment,
      @submission,
      params[:header_position],
      refresh: Time.now.to_i
    )
  end

private

  def set_problem
    @problem = @assessment.problems.find(params[:problem_id])
  end

  def set_rubric_item
    # For toggle action, find rubric item directly without going through problem
    @rubric_item = if action_name == 'toggle'
                     RubricItem.find(params[:id])
                   else
                     @problem.rubric_items.find(params[:id])
                   end
  end

  # Add this new method to set the problem from the rubric item when toggling
  def set_problem_from_rubric_item
    @problem = @rubric_item.problem
  end

  def set_submission
    @submission = @assessment.submissions.find(params[:submission_id])
  end

  def rubric_item_params
    params.require(:rubric_item).permit(:description, :points, :order)
  end
end
