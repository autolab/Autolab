require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe SubmissionsController, type: :controller do
  render_views

  shared_examples "index_success" do
    it "renders successfully" do
      sign_in(user)
      cud = get_first_cud_by_uid(user)
      cid = get_first_cid_by_uid(user)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      get :index, params: { course_name:, assessment_name: }
      expect(response).to be_successful
      expect(response.body).to match(/Manage Submissions/m)
    end
  end

  shared_examples "index_failure" do
    it "renders with failure" do
      sign_in(user)
      cud = get_first_cud_by_uid(user)
      cid = get_first_cid_by_uid(user)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      get :index, params: { course_name:, assessment_name: }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Manage Submissions/m)
    end
  end

  describe "#index" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "index_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Instructor" do
      it_behaves_like "index_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is student" do
      it_behaves_like "index_failure" do
        let!(:user) { student_user }
      end
    end

    context "when user is Course Assistant" do
      it_behaves_like "index_failure" do
        let!(:user) { course_assistant_user }
      end
    end
  end
end
