class ProblemsController < ApplicationController

  before_action :loadAssessment 

  action_auth_level :index, :instructor
  def index
    # not in use
  end

  action_auth_level :new, :instructor
  def new
    # we need to do zilch
  end

  action_auth_level :create, :instructor
  def create
    @problem = @assessment.problems.create(problem_params)
    if (@problem.save()) then
      redirect_to edit_course_assessment_path(@course, @assessment) and return
    else
      flash[:error] = "An error occurred while creating the new problem"
      redirect_to new_course_assessment_problem_path(@course, @assessment) and return
    end
  end

  action_auth_level :show, :instructor
  def show
    # not in use
  end

  action_auth_level :edit, :instructor
  def edit
    @problem = @assessment.problems.find(params[:id])
  end

  action_auth_level :update, :instructor
  def update
    @problem = @assessment.problems.find(params[:id])
    if (@problem.update(problem_params)) then
      flash[:success] = "Success: Problem saved"
    else
      flash[:error] = "Error: Problem not saved"
    end
    redirect_to edit_course_assessment_path(@course, @assessment) and return
  end

  action_auth_level :destroy, :instructor
  def destroy
    @problem = @assessment.problems.find(params[:id])
    if @problem.destroy() then
      flash[:success] = "Problem successfully destroyed."
    end
    redirect_to edit_course_assessment_path(@course, @assessment) and return
  end

# Non-RESTful routes below
  
  # this route is called when 'delete' is clicked, confirming the deletion
  action_auth_level :destroyConfirm, :instructor
  def destroyConfirm
    @problem = @assessment.problems.find(params[:id])
  end

protected
  
  # this loads the problem's assessment before anything else happens
  def loadAssessment
    @assessment = @course.assessments.find(params[:assessment_id])
    if @assessment.nil? then 
      flash[:error] = "Error: Course #{@course.display_name} has no Assessment with the given id."
      redirect_to home_error_path and return
    end
  end

private

  # this function says which problem attributes can be mass-assigned to, and which cannot
  def problem_params
    params.require(:problem).permit(:name, :description, :max_score, :optional)
  end

end
