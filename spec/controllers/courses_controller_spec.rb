require "rails_helper"

RSpec.describe CoursesController, type: :controller do
  render_views

  describe "#report_bug" do
    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :report_bug, params: {name: cname}
        expect(response).to be_successful
        expect(response.body).to match(/Stuck on a bug/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :report_bug, params: {name: cname}
        expect(response).not_to be_successful
        expect(response.body).not_to match(/Stuck on a bug/m)
      end
    end
  end

  describe "#user_lookup" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :user_lookup, params: {name: cname, email: u.email}
        expect(response).to be_successful
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :user_lookup, params: {name: cname, email: u.email}
        expect(response).to be_successful
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :user_lookup, params: {name: cname, email: u.email}
        expect(response).not_to be_successful
        expect(response.body).not_to match(/first_name/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      it "renders with failure" do
        get :user_lookup, params: {name: "dummy", email: u.email}
        expect(response).not_to be_successful
        expect(response.body).not_to match(/first_name/m)
      end
    end
  end

  describe "#update_lti_settings" do
    context "when user is autolab instructor" do
      course = course_with_instructor_and_lcd
      instructor = get_instructor_by_cid(course.id)
      login_as(instructor)
      it "updates lti settings" do
        patch :update_lti_settings, params: {name: course.name, lcd: {drop_missing_students: "1"}}
        expect(response).to have_http_status(302)
      end
    end
  end
end
