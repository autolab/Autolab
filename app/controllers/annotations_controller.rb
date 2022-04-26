# All modifications to the annotations are meant to be asynchronous and
# thus this contorller only exposes javascript interfaces.
#
# Only people acting as instructors or CA's should be able to do anything
# but view the annotations and since all of these mutate them, they are
# all restricted to those types.
class AnnotationsController < ApplicationController
  before_action :set_assessment
  before_action :set_submission
  before_action :set_annotation, except: [:create, :shared_comments]
  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

  respond_to :json

  # POST /:course/annotations.json
  action_auth_level :create, :course_assistant
  def create
    # primary annotation
    primary_annotation = @submission.annotations.new(annotation_params)

    if @submission.group_key.empty?
      # When the group key is empty, no group is involved
      ActiveRecord::Base.transaction do
        primary_annotation.save
        primary_annotation.update_non_autograded_score
      end
    else
      # Set up annotation group key = submission group key + problem id + timestamp
      tweaked_params = annotation_params
      submission_group_key = @submission.group_key
      annotation_group_key = "#{submission_group_key}_#{tweaked_params[:problem_id]}_"
      annotation_group_key += Time.current.utc.to_s(:number)

      # Set "primary" annotation's group key
      primary_annotation.group_key = annotation_group_key

      # Set shared comment to false to avoid duplicates in shared comment pool
      tweaked_params[:shared_comment] = false
      tweaked_params[:group_key] = annotation_group_key

      # All submissions of the iteration in the group, excluding the current one
      group_submissions = @submission.group_associated_submissions

      annotations = [primary_annotation]

      group_submissions.each do |group_submission|
        group_annotations.append(group_submission.annotations.new(tweaked_params))
      end

      ActiveRecord::Base.transaction do
        annotations.each do |annotation|
          annotation.save
          annotation.update_non_autograded_score
        end
      end
    end

    respond_with(@course, @assessment, @submission, primary_annotation)
  end

  # PUT /:course/annotations/1.json
  action_auth_level :update, :course_assistant
  def update
    if annotation.group_key.empty?
      ActiveRecord::Base.transaction do
        @annotation.update(annotation_params)
        @annotation.update_non_autograded_score
      end
    else
      annotations = @annotation.group_associated_annotations

      # Set shared comment to false to avoid duplicate shared comments
      tweaked_params = annotation_params
      tweaked_params[:shared_comment] = false

      ActiveRecord::Base.transaction do
        # Update "primary" annotation with native parameters
        @annotation.update(annotation_params)
        @annotation.update_non_autograded_score

        # Update group annotations with tweaked parameters
        annotations.each do |annotation|
          annotation.update(tweaked_params)
          annotation.update_non_autograded_score
        end
      end
    end

    respond_with(@course, @assessment, @submission, @annotation) do |format|
      format.json { render json: @annotation }
    end
  end

  # DELETE /:course/annotations/1.json
  action_auth_level :destroy, :course_assistant
  def destroy
    if @annotation.group_key.empty?
      ActiveRecord::Base.transaction do
        @annotation.destroy
        @annotation.update_non_autograded_score
      end
    else
      annotations = @annotation.group_associated_annotations
      ActiveRecord::Base.transaction do
        @annotation.destroy
        @annotation.update_non_autograded_score

        annotations.each do |annotation|
          annotation.destroy
          annotation.update_non_autograded_score
        end
      end
    end

    head :no_content
  end

  # GET /assessments/shared_comments
  # Gets all shared_comments of annotations
  action_auth_level :shared_comments, :course_assistant
  def shared_comments
    result = Annotation.select("annotations.id, annotations.comment")
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
    params.require(:annotation).permit(:filename, :position, :line, :submitted_by,
                                       :comment, :shared_comment, :value, :problem_id,
                                       :submission_id, :coordinate)
  end

  def set_annotation
    @annotation = @submission.annotations.find(params[:id])
  end
end
