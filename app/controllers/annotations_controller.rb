# All modifications to the annotations are meant to be asynchronous and 
# thus this contorller only exposes javascript interfaces.
#
# Only people acting as instructors or CA's should be able to do anything
# but view the annotations and since all of these mutate them, they are
# all restricted to those types.
class AnnotationsController < ApplicationController
  
  before_action :scrape_text, except: [:destroy]
  before_action :load_annotation, except: [:index, :new, :create]

  action_auth_level :index, :course_assistant
  def index
    # for REST completeness
  end

  action_auth_level :new, :course_assistant
  def new
    # for REST completeness
  end

  # POST /:course/annotations.js
  action_auth_level :create, :course_assistant
  def create
    assessment = @course.assessments.find(params[:assessment_id])
    submission = assessment.submissions.find(params[:submission_id])
    annotation = submission.annotations.new(annotation_params)
    respond_to do |format|
      if annotation.save

        description, value, line, problem = annotation.get_grades()[0]
        print
        print annotation
        annotationObj = {"text"=> annotation.text, 
                         "id"=> annotation.id,
                         "line"=>line,
                         "annotator"=> annotation.submitted_by,
                         "problem"=> problem}

        format.js { render json: annotationObj }
      else
        format.js { head :bad_request }
      end
    end
  end

  action_auth_level :show, :course_assistant
  def show
    # for REST completeness
  end

  action_auth_level :edit, :course_assistant
  def edit
    # for REST completeness
  end

  # PUT /:course/annotations/1.js
  action_auth_level :update, :course_assistant
  def update
    respond_to do |format|
      if @annotation && @annotation.update(annotation_params)
        format.js { render json: @annotation.as_json(only: [:text, :id]) }
      else
        format.js { head :bad_request }
      end
    end
  end

  # DELETE /:course/annotations/1.js
  action_auth_level :destroy, :course_assistant
  def destroy
    @annotation.destroy

    respond_to do |format|
      format.js { head :ok }
    end
  end

private
  def scrape_text
    params[:annotation][:line] = params[:annotation][:line].to_i + 1
    params[:annotation][:text] = Annotation.parse_input(params[:annotation][:text],
                                                        params[:annotation][:line],
                                                        session[:problems])
  end

  def annotation_params
    params.require(:annotation).permit(:filename, :position, 
              :line, :text, :submitted_by, :comment, :value)
  end

  def load_annotation
    assessment = @course.assessments.find(params[:assessment_id])
    submission = assessment.submissions.find(params[:submission_id])
    @annotation = submission.annotations.find(params[:id])
  end
end
