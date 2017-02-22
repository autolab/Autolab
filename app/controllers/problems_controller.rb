##
# An Assessment can have any number of Problems, which are basically just a name,
# and a think for Scores to join with.
#
class ProblemsController < ApplicationController
  # inherited from ApplicationController
  before_action :set_assessment
  before_action :set_problem, only: [:edit, :update, :destroy]
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :new, :instructor
  def new
    @breadcrumbs << (view_context.link_to "Problems", problems_index)
  end

  action_auth_level :create, :instructor
  def create
    @problem = @assessment.problems.new(problem_params)
    if @problem.save
      redirect_to(problems_index) && return
    else
      flash[:error] = "An error occurred while creating the new problem"
      redirect_to([:new, @course, @assessment, :problem]) && return
    end
  end

  action_auth_level :edit, :instructor
  def edit
  end

  action_auth_level :update, :instructor
  def update
    if @problem.update(problem_params)
      flash[:success] = "Success: Problem saved"
    else
      flash[:error] = "Error: Problem not saved"
    end
    redirect_to(problems_index) && return
  end

  action_auth_level :destroy, :instructor
  def destroy
    flash[:success] = "Problem successfully destroyed." if @problem.destroy
    redirect_to(problems_index) && return
  end

private

  def set_problem
    @problem = @assessment.problems.find(params[:id])
    @breadcrumbs << (view_context.link_to "Problems", problems_index)
  end

  ##
  # creates a link to the problems page, which is a tab on assessments#edit
  #
  def problems_index
    edit_course_assessment_path(@course, @assessment) + "/problems"
  end

  # this function says which problem attributes can be mass-assigned to, and which cannot
  def problem_params
    params.require(:problem).permit(:name, :description, :max_score, :optional)
  end
end
