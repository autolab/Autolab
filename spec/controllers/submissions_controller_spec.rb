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
        get :index, params: { course_name: course_name, assessment_name: assessment_name }
        expect(response).to be_successful
        expect(response.body).to match(/Manage Submissions/m)
      end
    end

    context "when user is Instructor" do
      user_id = get_instructor
      login_as(user_id)
      cud = get_first_cud_by_uid(user_id)
      cid = get_course_id_by_uid(user_id)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      it "renders successfully" do
        get :index, params: { course_name: course_name, assessment_name: assessment_name }
        expect(response).to be_successful
        expect(response.body).to match(/Manage Submissions/m)
      end
    end

    context "when user is student" do
      user_id = get_user
      login_as(user_id)
      cud = get_first_cud_by_uid(user_id)
      cid = get_course_id_by_uid(user_id)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      it "renders with failure" do
        get :index, params: { course_name: course_name, assessment_name: assessment_name }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Manage Submissions/m)
      end
    end

    context "when user is course assistant" do
      cid = get_first_course
      user_id = create_ca_for_course(cid, "courseassistant@test.com", "course", "assistant",
                                     "12345678")
      cud = get_first_cud_by_uid(user_id)
      cid = get_course_id_by_uid(user_id)
      course_name = Course.find(cid).name
      assessment_id = get_first_aid_by_cud(cud)
      assessment_name = Assessment.find(assessment_id).name
      it "renders with failure" do
        get :index, params: { course_name: course_name, assessment_name: assessment_name }
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Manage Submissions/m)
      end
    end
  end
end
