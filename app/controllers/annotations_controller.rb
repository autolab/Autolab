# All modifications to the annotations are meant to be asynchronous and
# thus this controller only exposes javascript interfaces.
#
# Only people acting as instructors or CA's should be able to do anything
# but view the annotations and since all of these mutate them, they are
# all restricted to those types.
class AnnotationsController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_annotation, except: [:create, :shared_comments]
  respond_to :json

  # POST /:course/annotations.json
  action_auth_level :create, :course_assistant
  def create
    annotation = @submission.annotations.new(annotation_params)

    ActiveRecord::Base.transaction do
      annotation.save
      annotation.update_non_autograded_score
    end

    respond_with(@course, @assessment, @submission, annotation)
  end

  # PUT /:course/annotations/1.json
  action_auth_level :update, :course_assistant
  def update
    tweaked_params = annotation_params
    tweaked_params.delete(:submission_id)
    tweaked_params.delete(:filename)
    ActiveRecord::Base.transaction do
      # Remove effect of annotation to handle updating annotation problem
      @annotation.update({ "value" => "0" })
      @annotation.update_non_autograded_score

      @annotation.update(tweaked_params)
      @annotation.update_non_autograded_score
    end

    respond_with(@course, @assessment, @submission, @annotation) do |format|
      format.json { render json: @annotation }
    end
  end

  # DELETE /:course/annotations/1.json
  action_auth_level :destroy, :course_assistant
  def destroy
    ActiveRecord::Base.transaction do
      @annotation.destroy
      @annotation.update_non_autograded_score
    end

    head :no_content
  end

  # GET /assessments/shared_comments
  # Gets all shared_comments of annotations
  action_auth_level :shared_comments, :course_assistant
  def shared_comments
    result = Annotation.select("annotations.id,
                                annotations.comment,
                                annotations.problem_id,
                                annotations.value")
                       .joins(:submission).where(shared_comment: true)
                       .where("submissions.assessment_id = ?", @assessment.id)
                       .order(updated_at: :desc).limit(50).as_json

    render json: result, status: :ok
  end

private

  def annotation_params
    params[:annotation].delete(:id)
    params[:annotation].delete(:created_at)
    params[:annotation].delete(:updated_at)
    # Prevent spoofing the submitter
    params[:annotation][:submitted_by] = @current_user.email
    params.require(:annotation).permit(:filename, :position, :line, :submitted_by,
                                       :comment, :shared_comment, :global_comment, :value,
                                       :problem_id, :submission_id, :coordinate)
  end

  def set_annotation
    @annotation = Annotation.find_by(id: params[:id])
  end
end
