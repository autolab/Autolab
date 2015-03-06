class ScoresController < ApplicationController

  before_action :set_assessment
  before_action :set_submission
  before_action :set_score, except: [:create]
  
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
  end

  action_auth_level :update, :course_assistant
  def update
    respond_to do |format|
       if @score && @score.update_attributes({:score => params[:score],
                                            :feedback => params[:feedback],
                                            :grader_id => params[:grader_id],
                                            :released => params[:released]})
         format.js { render :json => @score.to_json(:include => :grader) }
       else
         format.js { head :bad_request }
       end 
    end
  end

  private

    def set_submission
      @submission = @assessment.submissions.find(params[:submission_id])
    
      unless (@cud.instructor or @cud.course_assistant or @submission.course_user_datum_id == @cud.id) then
        flash[:error] = "You do not have permission to access this submission."
        redirect_to controller: :home, action: :error and return false
      end

      if (@assessment.exam? or @course.exam_in_progress?) and not (@cud.instructor or @cud.course_assistant) then
        flash[:error] = "You cannot view this submission.
                Either an exam is in progress or this is an exam submission."
        redirect_to controller: :home, action: :error and return false
      end
      return true
    end
    
    def set_score
      @score = @submission.scores.find(params[:id])
      unless (@score.submission.course_user_datum_id == @cud.id) || 
             (@cud.has_auth_level? :course_assistant) then
        redirect_to :action=>"index" and return 
      end
    end

end
