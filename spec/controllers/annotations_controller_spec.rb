require "rails_helper"
include ControllerMacros

RSpec.describe AnnotationsController, type: :controller do
  render_views

  shared_examples "create_success" do
    it "renders successfully" do
      sign_in(user)

      problem = assessment.problems.first
      submission = assessment.submissions.first

      annotation_params = {
        filename: submission.filename, position: 0, line: 1,
        submitted_by: user.id, shared_comment: false,
        global_comment: false, problem_id: problem.id, coordinate: nil,
        submission_id: submission.id, comment: "test", value: 0
      }

      post :create, params: { course_name: course.name,
                              assessment_name: assessment.name,
                              submission_id: submission.id,
                              annotation: annotation_params }
      expect(response).to be_successful
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
  end
end
