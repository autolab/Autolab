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
      update_non_autograded_score(annotation)
    end

    respond_with(@course, @assessment, @submission, annotation)
  end

  # PUT /:course/annotations/1.json
  action_auth_level :update, :course_assistant
  def update
    ActiveRecord::Base.transaction do
      @annotation.update(annotation_params)
      update_non_autograded_score(@annotation)
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
      update_non_autograded_score(@annotation)
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

  # Update all non-autograded scores with the following formula:
  # score_p = max_score_p + sum of annotations for problem
  def update_non_autograded_score(annotation)
    # Get score for submission, or create one if it does not already exist
    # Previously, scores would be created when instructors add a score
    # and save on the gradebook
    score = Score.find_or_initialize_by_submission_id_and_problem_id(
        annotation.submission_id, annotation.problem_id)

    # Ensure that problem is non-autograded
    if score.grader_id == 0
      return
    end

    # If score was newly-created, we need to add a grader_id to score
    if score.grader.nil?
      score.grader_id = CourseUserDatum.find_by(user_id: User.find_by_email(annotation.submitted_by).id,
                                          course_id: @course.id).id
    end

    # Obtain sum of all annotations for this score
    annotation_delta = Annotation.
        where(submission_id: annotation.submission_id,
              problem_id: annotation.problem_id).
        map(&:value).sum{|v| v.nil? ? 0 : v}

    new_score = score.problem.max_score + annotation_delta

    # Update score
    score.update!(score: new_score)
  end
end
