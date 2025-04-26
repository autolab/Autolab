class RubricItemsController < ApplicationController
  before_action :set_assessment
  before_action :set_problem
  before_action :set_rubric_item, only: [:edit, :update, :destroy]

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
  def edit
  end

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

  private

  def set_problem
    @problem = @assessment.problems.find(params[:problem_id])
  end

  def set_rubric_item
    @rubric_item = @problem.rubric_items.find(params[:id])
  end

  def rubric_item_params
    params.require(:rubric_item).permit(:description, :points, :order)
  end
end 