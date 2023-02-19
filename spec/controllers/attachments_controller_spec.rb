require "rails_helper"
include ControllerMacros

RSpec.describe AttachmentsController, type: :controller do
  render_views

  # Course attachments

  # INDEX
  shared_examples "index_success" do |u|
    login_as(u)
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

  # NEW
  shared_examples "new_success" do |u|
    login_as(u)
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders successfully" do
      get :new, params: {course_name: cname}
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Released/m)
    end
  end

  shared_examples "new_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders with failure" do
      get :new, params: {course_name: cname}
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Released/m)
    end
  end

  describe "#new" do
    context "when user is Autolab admin" do
      it_behaves_like "new_success", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "new_success", get_instructor
    end

    context "when user is Autolab user" do
      it_behaves_like "new_failure", get_user
    end

    context "when user is not logged in" do
      it_behaves_like "new_failure", get_admin, login: false
    end
  end

  # EDIT
  shared_examples "edit_success" do |u|
    login_as(u)
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
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

  shared_examples "edit_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
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

  describe "#edit" do
    context "when user is Autolab admin" do
      it_behaves_like "edit_success", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "edit_success", get_instructor
    end

    context "when user is Autolab user" do
      it_behaves_like "edit_failure", get_user
    end

    context "when user is not logged in" do
      it_behaves_like "edit_failure", get_admin, login: false
    end
  end

  # SHOW
  shared_examples "show_success" do |u, released: true|
    login_as(u)
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, released) }
    it "renders successfully" do
      get :show, params: {course_name: cname, id: att.id}
      expect(response).to be_successful
    end
  end

  shared_examples "show_failure" do |u, login: true, released: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, released) }
    it "renders with failure" do
      get :show, params: {course_name: cname, id: att.id}
      expect(response).not_to be_successful
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      it_behaves_like "show_success", get_admin
      it_behaves_like "show_success", get_admin, released: false
    end

    context "when user is Autolab instructor" do
      it_behaves_like "show_success", get_instructor
      it_behaves_like "show_success", get_instructor, released: false
    end

    context "when user is Autolab user" do
      it_behaves_like "show_success", get_user
      it_behaves_like "show_failure", get_user, released: false
    end

    context "when user is not logged in" do
      it_behaves_like "show_failure", get_admin, login: false
      it_behaves_like "show_failure", get_admin, login: false, released: false
    end
  end
end
