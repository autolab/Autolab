class Api::V1::ProblemsController < Api::V1::BaseApiController

  before_action -> { require_privilege :user_courses }, only: [:index]
  before_action -> { require_privilege :instructor_all }, only: [:create]

  before_action :set_assessment

  # endpoint for obtaining details about all problems of an assessment
  def index
    problems = @assessment.problems

    respond_with problems, only: [:name, :description, :max_score, :optional, :starred]
  end

  # endpoint for creating a problem for an assessment
  def create
    require_params([:name, :max_score])
    set_default_params({ description: "", optional: false, starred: false })

    problem = @assessment.problems.new(problem_params)
    unless problem.save
      raise ApiError.new("Unable to create problem", :internal_server_error)
    end

    render json: format_problem_response(problem), status: :created
  end

private

  # this function says which problem attributes can be mass-assigned to, and which cannot
  def problem_params
    params.permit(:name, :description, :max_score, :optional, :starred)
  end

  def format_problem_response(problem)
    problem.as_json(only: [:name, :description, :max_score, :optional, :starred])
  end
end
