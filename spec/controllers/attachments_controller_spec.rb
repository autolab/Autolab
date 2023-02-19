require "rails_helper"
include ControllerMacros

RSpec.describe AttachmentsController, type: :controller do
  render_views

  # Course attachments

  # INDEX
  shared_examples "index_success" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders successfully" do
      get :index, params: {course_name: cname}
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(/Course Attachments/m)
    end
  end

  shared_examples "index_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders with failure" do
      get :index, params: {course_name: cname}
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(/Course Attachments/m)
    end
  end

  describe "#index" do
    context "when user is Autolab admin" do
      it_behaves_like "index_success", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "index_success", get_instructor
    end

    context "when user is Autolab user" do
      it_behaves_like "index_failure", get_user
    end

    context "when user is not logged in" do
      it_behaves_like "index_failure", get_admin, login: false
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
        expect(response).to be_successful
        expect(response.body).to match(cname)
        expect(response.body).to match(/Name/m)
        expect(response.body).to match(/Released/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders successfully" do
        get :new, params: {course_name: cname}
        expect(response).to be_successful
        expect(response.body).to match(cname)
        expect(response.body).to match(/Name/m)
        expect(response.body).to match(/Released/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :new, params: {course_name: cname}
        expect(response).not_to be_successful
        expect(response.body).not_to match(cname)
        expect(response.body).not_to match(/Name/m)
        expect(response.body).not_to match(/Released/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      it "renders with failure" do
        get :new, params: {course_name: cname}
        expect(response).not_to be_successful
        expect(response.body).not_to match(cname)
        expect(response.body).not_to match(/Name/m)
        expect(response.body).not_to match(/Released/m)
      end
    end
  end

  describe "#edit" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders successfully" do
        get :edit, params: {course_name: cname, id: att.id}
        expect(response).to be_successful
        expect(response.body).to match(cname)
        expect(response.body).to match(att.name)
        expect(response.body).to match("text/plain")
        expect(response.body).to match(/Name/m)
        expect(response.body).to match(/Released/m)
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders successfully" do
        get :edit, params: {course_name: cname, id: att.id}
        expect(response).to be_successful
        expect(response.body).to match(cname)
        expect(response.body).to match(att.name)
        expect(response.body).to match("text/plain")
        expect(response.body).to match(/Name/m)
        expect(response.body).to match(/Released/m)
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders with failure" do
        get :edit, params: {course_name: cname, id: att.id}
        expect(response).not_to be_successful
        expect(response.body).not_to match(cname)
        expect(response.body).not_to match(att.name)
        expect(response.body).not_to match("text/plain")
        expect(response.body).not_to match(/Name/m)
        expect(response.body).not_to match(/Released/m)
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders with failure" do
        get :edit, params: {course_name: cname, id: att.id}
        expect(response).not_to be_successful
        expect(response.body).not_to match(cname)
        expect(response.body).not_to match(att.name)
        expect(response.body).not_to match("text/plain")
        expect(response.body).not_to match(/Name/m)
        expect(response.body).not_to match(/Released/m)
      end
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      u = get_admin
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders successfully" do
        get :show, params: {course_name: cname, id: att.id}
        expect(response).to be_successful
      end
    end

    context "when user is Autolab instructor" do
      u = get_instructor
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders successfully" do
        get :show, params: {course_name: cname, id: att.id}
        expect(response).to be_successful
      end
    end

    context "when user is Autolab user" do
      u = get_user
      login_as(u)
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders successfully" do
        get :show, params: {course_name: cname, id: att.id}
        expect(response).to be_successful
      end
    end

    context "when user is not logged in" do
      u = get_admin
      cid = get_course_id_by_uid(u.id)
      cname = Course.find(cid).name
      let!(:att) { create_course_att_with_cid(cid, true) }
      it "renders with failure" do
        get :show, params: {course_name: cname, id: att.id}
        expect(response).not_to be_successful
      end
    end
  end
end
