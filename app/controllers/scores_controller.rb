##
# There's a score for each problem and each submission in every assessment.
# That is A LOT OF SCORES.
#
class ScoresController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_score, except: [:create]

  action_auth_level :create, :course_assistant
  def create
    score = Score.new
    respond_to do |format|
      if score.update(create_params)
        format.js { render json: score.to_json(include: :grader) }
      else
        format.js { head :bad_request }
      end
    end
  end

  action_auth_level :show, :course_assistant
  def show; end

  action_auth_level :update, :course_assistant
  def update
    respond_to do |format|
      if @score&.update(update_params)
        format.js { render json: @score.to_json(include: :grader) }
      else
        format.js { head :bad_request }
      end
    end
  end

private

  def set_score
    @score = @submission.scores.find(params[:id])
    return if (@score.submission.course_user_datum_id == @cud.id) ||
              (@cud.has_auth_level? :course_assistant)

    flash[:error] = "Action not allowed"
    redirect_to(action: "index") && return
  end

  def create_params
    params.permit(:score, :feedback, :grader_id, :released, :problem_id, :submission_id)
  end

  def update_params
    params.permit(:score, :feedback, :grader_id, :released)
  end
end
