require "rails_helper"
require "fileutils"

RSpec.describe SchedulersController, type: :controller do
  render_views

  describe "#index" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :index, params: {course_name: cname}
        expect(response).to be_success
        expect(response.body).to match(/Manage Schedulers/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :index, params: {course_name: cname}
        expect(response).to be_success
        expect(response.body).to match(/Manage Schedulers/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :index, params: {course_name: cname}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Manage Schedulers/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :index, params: {course_name: "dummy"}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Manage Schedulers/m)
      end
    end
  end

  describe "#new" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :new, params: {course_name: cname}
        expect(response).to be_success
        expect(response.body).to match(/New scheduler/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :new, params: {course_name: cname}
        expect(response).to be_success
        expect(response.body).to match(/New scheduler/m)
      end
    end


    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :new, params: {course_name: cname}
        expect(response).not_to be_success
        expect(response.body).not_to match(/New scheduler/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :new, params: {course_name: "dummy"}
        expect(response).not_to be_success
        expect(response.body).not_to match(/New scheduler/m)
      end
    end
  end

  describe "#edit" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :edit, params: {course_name: cname, id: s.id}
        expect(response).to be_success
        expect(response.body).to match(/Editing scheduler/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :edit, params: {course_name: cname, id: s.id}
        expect(response).to be_success
        expect(response.body).to match(/Editing scheduler/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :edit, params: {course_name: cname, id: s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Editing scheduler/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :edit, params: {course_name: "dummy", id: s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Editing scheduler/m)
      end
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :show, params: {course_name: cname, id: s.id}
        expect(response).to be_success
        expect(response.body).to match(/Action:/m)
        expect(response.body).to match(/Interval:/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders successfully" do
        get :show, params: {course_name: cname, id: s.id}
        expect(response).to be_success
        expect(response.body).to match(/Action:/m)
        expect(response.body).to match(/Interval:/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :show, params: {course_name: cname, id: s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Action:/m)
        expect(response.body).not_to match(/Interval:/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      s = create_scheduler_with_cid(cid)
      it "renders with failure" do
        get :show, params: {course_name: "dummy", id: s.id}
        expect(response).not_to be_success
        expect(response.body).not_to match(/Action:/m)
        expect(response.body).not_to match(/Interval:/m)
      end
    end
  end
end
