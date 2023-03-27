require "rails_helper"
include ControllerMacros

RSpec.describe AnnotationsController, type: :controller do
  render_views

  describe "#create" do
    include_context "controllers shared context"
    context "when user is instructor" do
      it "renders successfully" do
        sign_in(instructor_user)

        problem = assessment.problems.first
        submission = assessment.submissions.first

        annotation_params = {
          filename: submission.filename, position: 0, line: 1,
          submitted_by: instructor_user.id, shared_comment: false,
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

    #  context "when user is not logged in" do
    #    it "renders with failure" do
    #      cid = get_first_cid_by_uid(student_user.id)
    #      cname = Course.find(cid).name
    #      get :report_bug, params: { name: cname }
    #      expect(response).not_to be_successful
    #      expect(response.body).not_to match(/Stuck on a bug/m)
    #    end
    #  end
  end
end
