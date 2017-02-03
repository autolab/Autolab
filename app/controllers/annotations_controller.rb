# All modifications to the annotations are meant to be asynchronous and
# thus this contorller only exposes javascript interfaces.
#
# Only people acting as instructors or CA's should be able to do anything
# but view the annotations and since all of these mutate them, they are
# all restricted to those types.
class AnnotationsController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_annotation, except: [:create]
    rescue_from ActionView::MissingTemplate do |exception|
      redirect_to("/home/error_404")
  end

  respond_to :json

  # POST /:course/annotations.json
  action_auth_level :create, :course_assistant
  def create
     #check to see if given score is greater than max possible score for the problem 
     if !annotation_params[:problem_id].blank? 
      maxScore = Problem.find(annotation_params[:problem_id]).max_score.to_f
      if annotation_params[:value].to_f > maxScore
        render :status => 422, :text => "bad data"
        return
      end 
    end

    findanno = Annotation.where('submission_id = ? AND problem_id = ?', params[:submission_id] , annotation_params[:problem_id])
    if !findanno.blank?
       render :status => 422, :text => "bad data"
       return
    end



    annotation = @submission.annotations.new(annotation_params)

    #check to see if a problem was selected in the select box or not
    if !annotation_params[:problem_id].blank? 
      findScore = Score.where('submission_id = ? AND problem_id = ?', params[:submission_id] , annotation_params[:problem_id])
    else
      annotation.save
      respond_with(@course, @assessment, @submission, annotation)
      return
    end    
    # set all of the data and insert the score into the table if it doesnt already exists if it does update the entry
    if findScore.blank?
      score = Score.new
      score.submission_id =  params[:submission_id]
      score.score = annotation_params[:value]
      score.problem_id = annotation_params[:problem_id]
      score.released = 0
      score.grader_id = @cud.id
      score.save
    else
      findScore.first.score = annotation_params[:value]
      findScore.first.grader_id = @cud.id
      findScore.first.save
    end 
    annotation.save

    respond_with(@course, @assessment, @submission, annotation)
  end

  # PUT /:course/annotations/1.json
  action_auth_level :update, :course_assistant
  def update
     #check to see if given score is greater than max possible score for the problem 
    maxScore = Problem.find(annotation_params[:problem_id]).max_score.to_f
    if annotation_params[:value].to_f > maxScore
      render :status => 422, :text => "bad data"
      return
    end 
    #  check to see if a problem was selected
    if !annotation_params[:problem_id].blank?
      findScore = Score.where('submission_id = ? AND problem_id = ?', params[:submission_id], annotation_params[:problem_id])
      @annotation.update(annotation_params)
    else
      @annotation.update(annotation_params)
      respond_with(@course, @assessment, @submission, @annotation) do |format|
        format.json { render json: @annotation }
      end
      return
    end
    # update the score if it exists.
    if !findScore.blank?
      findScore.first.problem_id = annotation_params[:problem_id]
      findScore.first.grader_id = @cud.id
      findScore.first.score = annotation_params[:value]
      findScore.first.save
    else
      score = Score.new
      score.submission_id =  params[:submission_id]
      score.score = annotation_params[:value]
      score.problem_id = annotation_params[:problem_id]
      score.released = 0
      score.grader_id = @cud.id
      score.save
    end

    respond_with(@course, @assessment, @submission, @annotation) do |format|
      format.json { render json: @annotation }
    end
  end

  # DELETE /:course/annotations/1.json
  action_auth_level :destroy, :course_assistant
  def destroy
    # remove score entry and delete annoation
    if !@annotation.problem_id.blank?
      Score.where('submission_id = ? AND problem_id = ?', @annotation.submission_id , @annotation.problem_id).first.destroy
    end
    @annotation.destroy
    head :no_content
  end

private

  def annotation_params
    params[:annotation].delete(:id)
    params[:annotation].delete(:created_at)
    params[:annotation].delete(:updated_at)
    params.require(:annotation).permit(:filename, :position, :line, :text, :submitted_by,
                                       :comment, :value, :problem_id,:submission_id, :coordinate)
  end

  def set_annotation
    @annotation = @submission.annotations.find(params[:id])
  end
end