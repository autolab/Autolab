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
    annotation = @submission.annotations.new(annotation_params)

    ActiveRecord::Base.transaction do
      annotation.save
      annotation.update_non_autograded_score()
    end

    respond_with(@course, @assessment, @submission, annotation)
  end

  # PUT /:course/annotations/1.json
  action_auth_level :update, :course_assistant
  def update
    ActiveRecord::Base.transaction do
      @annotation.update(annotation_params)
      @annotation.update_non_autograded_score()
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
      @annotation.update_non_autograded_score()
    end

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
