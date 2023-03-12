require "rails_helper"
include ControllerMacros

RSpec.describe SubmissionsController, type: :controller do
  render_views

  shared_examples "index_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      cud = get_first_cud_by_uid(user)
      cid = get_course_id_by_uid(user)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      get :index, params: { course_name: course_name, assessment_name: assessment_name }
      expect(response).to be_successful
      expect(response.body).to match(/Manage Submissions/m)
    end
  end

  shared_examples "index_failure" do
    before(:each) do
      sign_in(user)
    end
    it "renders with failure" do
      cud = get_first_cud_by_uid(user)
      cid = get_course_id_by_uid(user)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      get :index, params: { course_name: course_name, assessment_name: assessment_name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Manage Submissions/m)
    end
  end

  describe "#index" do
    context "when user is Autolab admin" do
      it_behaves_like "index_success" do
        let!(:user) do
          create_course_with_users
          @admin_user
        end
      end
    end

    context "when user is Instructor" do
      it_behaves_like "index_success" do
        let!(:user) do
          create_course_with_users
          @instructor_user
        end
      end
    end

    context "when user is student" do
      it_behaves_like "index_failure" do
        let!(:user) do
          create_course_with_users
          @students.first
        end
      end
    end

    context "when user is Instructor" do
      it_behaves_like "index_failure" do
        let!(:user) do
          create_course_with_users
          @course_assistant_user
        end
      end
    end
  end
end
