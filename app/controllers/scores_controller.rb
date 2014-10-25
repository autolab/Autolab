class ScoresController < ApplicationController

  before_action :get_assessment_and_submission
  
  action_auth_level :index, :course_assistant
  def index

  end

  action_auth_level :new, :course_assistant
  def new

  end

  action_auth_level :create, :course_assistant
  def create
    score = Score.new
    score.update_attributes({:score => params[:score],
                            :feedback => params[:feedback],
                            :grader_id => params[:grader_id],
                            :released => params[:released],
                            :problem_id => params[:problem_id],
                            :submission_id => params[:submission_id]})
    respond_to do |format| 
      if score.save
        format.js { render :json => score.to_json(:include => :grader) }
      else
        format.js { head :bad_request }
      end
    end
  end

  action_auth_level :show, :course_assistant
  def show
    # code copied from viewFeedback
    #User requested to view feedback on a score
    @score = Score.where(submission_id: params[:submission_id]).first
    if !@score then
      redirect_to :action=>"index" and return
    end
    unless (@score.submission.course_user_datum_id == @cud.id) || 
           (@cud.has_auth_level? :course_assistant) then
        redirect_to :action=>"index" and return 
    end 
    
    @submission = @score.submission

    return

    #old code
    score = Score.find(params[:id])
    respond_to do |format|
      if score
        format.js { render :json => score.to_json(:include => :grader) }
      else
        format.js { head :bad_request }
      end
    end
  end

  action_auth_level :edit, :course_assistant
  def edit

  end

  action_auth_level :update, :course_assistant
  def update
    score = Score.find(params[:id])
    respond_to do |format|
       if score && score.update_attributes({:score => params[:score],
                                            :feedback => params[:feedback],
                                            :grader_id => params[:grader_id],
                                            :released => params[:released]})
         format.js { render :json => score.to_json(:include => :grader) }
       else
         format.js { head :bad_request }
       end 
    end
  end

  action_auth_level :destroy, :course_assistant
  def destroy

  end

private

  def get_assessment_and_submission
    @submission = Submission.find(params[:submission_id])
    @assessment = Assessment.find(params[:assessment_id])
  end

end
