require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe AnnotationsController, type: :controller do
  render_views

  let(:base_annotation) do
    {
      position: 0, line: 1, submitted_by: user.id, shared_comment: false,
      global_comment: false, coordinate: nil, comment: "test", value: 0
    }
  end

  shared_examples "create_success" do
    it "renders successfully" do
      sign_in(user)

      problem = get_first_problem_by_assessment(assessment.id)
      submission = get_first_submission_by_assessment(assessment.id)

      annotation_params = {
        problem_id: problem.id,
        submission_id: submission.id,
        filename: submission.filename,
        **base_annotation
      }

      post :create, params: { course_name: course.name,
                              assessment_name: assessment.name,
                              submission_id: submission.id,
                              annotation: annotation_params }
      expect(response).to be_successful
    end
  end

  shared_examples "create_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login

      problem = get_first_problem_by_assessment(assessment.id)
      submission = get_first_submission_by_assessment(assessment.id)

      annotation_params = {
        problem_id: problem.id,
        submission_id: submission.id,
        filename: submission.filename,
        **base_annotation
      }

      post :create, params: { course_name: course.name,
                              assessment_name: assessment.name,
                              submission_id: submission.id,
                              annotation: annotation_params }
      expect(response).not_to be_successful
    end
  end

  describe "#create" do
    include_context "controllers shared context"

    context "when user is Autolab admin" do
      it_behaves_like "create_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "create_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab course assistant" do
      it_behaves_like "create_success" do
        let!(:user) { course_assistant_user }
      end
    end

    context "when user is Autolab student" do
      it_behaves_like "create_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "create_failure", login: false do
        let!(:user) { admin_user }
      end
    end
  end
end
