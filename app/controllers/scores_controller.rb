##
# There's a score for each problem and each submission in every assessment.
# That is A LOT OF SCORES.
#
class ScoresController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_score, except: [:create]
  rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  action_auth_level :create, :course_assistant
  def create
    score = Score.new
    score.update_attributes(score: params[:score],
                            feedback: params[:feedback],
                            grader_id: params[:grader_id],
                            released: params[:released],
                            problem_id: params[:problem_id],
                            submission_id: params[:submission_id])
    respond_to do |format|
      if score.save
        format.js { render json: score.to_json(include: :grader) }
      else
        format.js { head :bad_request }
      end
    end
  end

  action_auth_level :show, :course_assistant
  def show
  end

  action_auth_level :update, :course_assistant
  def update
    respond_to do |format|
      if @score && @score.update_attributes(score: params[:score],
                                            feedback: params[:feedback],
                                            grader_id: params[:grader_id],
                                            released: params[:released])
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
    redirect_to(action: "index") && return
  end
end
