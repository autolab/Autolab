require "rails_helper"

RSpec.describe CoursesController, type: :controller do
  render_views

  describe "#report_bug" do
    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :report_bug, course_id: cid
        expect(response).to be_success
        expect(response.body).to match(/Stuck on a bug/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      it "renders with failure" do
        get :report_bug, course_id: cid
        expect(response).not_to be_success
        expect(response.body).not_to match(/Stuck on a bug/m)
      end
    end
  end

  describe "#userLookup" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :userLookup, course_id: cid, email: u.email
        expect(response).to be_success
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders successfully" do
        get :userLookup, course_id: cid, email: u.email
        expect(response).to be_success
        expect(response.body).to match(/first_name/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      it "renders with failure" do
        get :userLookup, course_id: cid, email: u.email
        expect(response).not_to be_success
        expect(response.body).not_to match(/first_name/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      it "renders with failure" do
        get :userLookup, course_id: 1, email: u.email
        expect(response).not_to be_success
        expect(response.body).not_to match(/first_name/m)
      end
    end
  end
end
