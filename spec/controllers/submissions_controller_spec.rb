require "rails_helper"

RSpec.describe SubmissionsController, type: :controller do
  render_views

  describe "#index" do
    context "when user is Autolab admin" do
      user_id = get_admin
      login_as(user_id)
      cud = get_first_cud_by_uid(user_id)
      cid = get_course_id_by_uid(user_id)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      it "renders successfully" do
        get :index, params: {course_name: course_name, assessment_name: assessment_name}
        expect(response).to be_successful
        expect(response.body).to match(/Manage Submissions/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders successfully" do
        get :index
        expect(response).to be_successful
        expect(response.body).to match(/Users List/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :index
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Users List/m)
      end
    end
  end
end