require "rails_helper"
include ControllerMacros

RSpec.describe AttachmentsController, type: :controller do
  render_views

  # Render tests

  # INDEX
  shared_examples "index_success" do |u|
    login_as(u)
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders course successfully" do
      get :index, params: { course_name: cname }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(/Course Attachments/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "renders assessment successfully" do
      get :index, params: { course_name: cname, assessment_name: aname }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(aname)
      expect(response.body).to match(/Add/m)
    end
  end

  shared_examples "index_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders course with failure" do
      get :index, params: { course_name: cname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(/Course Attachments/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "renders assessment with failure" do
      get :index, params: { course_name: cname, assessment_name: aname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(aname)
      expect(response.body).not_to match(/Add/m)
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
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders course successfully" do
      get :new, params: { course_name: cname }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Released/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "renders assessment successfully" do
      get :new, params: { course_name: cname, assessment_name: aname }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(aname)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Released/m)
    end
  end

  shared_examples "new_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "renders course with failure" do
      get :new, params: { course_name: cname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Released/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "renders assessment with failure" do
      get :new, params: { course_name: cname, assessment_name: aname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(aname)
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
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, true) }
    it "renders course successfully" do
      get :edit, params: { course_name: cname, id: att.id }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(att.name)
      expect(response.body).to match(att.mime_type)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Mime type/m)
      expect(response.body).to match(/Released/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    let!(:assess_att) { create_assess_att_with_cid_aid(cid, aid, true) }
    it "renders assessment successfully" do
      get :edit, params: { course_name: cname, assessment_name: aname, id: assess_att.id }
      expect(response).to be_successful
      expect(response.body).to match(cname)
      expect(response.body).to match(aname)
      expect(response.body).to match(assess_att.name)
      expect(response.body).to match(assess_att.mime_type)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Mime type/m)
      expect(response.body).to match(/Released/m)
    end
  end

  shared_examples "edit_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, true) }
    it "renders course with failure" do
      get :edit, params: { course_name: cname, id: att.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(att.name)
      expect(response.body).not_to match(att.mime_type)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Mime type/m)
      expect(response.body).not_to match(/Released/m)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    let!(:assess_att) { create_assess_att_with_cid_aid(cid, aid, true) }
    it "renders assessment with failure" do
      get :edit, params: { course_name: cname, assessment_name: aname, id: assess_att.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(cname)
      expect(response.body).not_to match(aname)
      expect(response.body).not_to match(assess_att.name)
      expect(response.body).not_to match(assess_att.mime_type)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Mime type/m)
      expect(response.body).not_to match(/Released/m)
    end
  end

  shared_examples "edit_missing" do |u|
    login_as(u)
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "flashes error for non-existent course attachment" do
      get :edit, params: { course_name: cname, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "flashes error for non-existent assessment attachment" do
      get :edit, params: { course_name: cname, assessment_name: aname, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
  end

  describe "#edit" do
    context "when user is Autolab admin" do
      it_behaves_like "edit_success", get_admin
      it_behaves_like "edit_missing", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "edit_success", get_instructor
      it_behaves_like "edit_missing", get_instructor
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
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, released) }
    it "renders course successfully" do
      get :show, params: { course_name: cname, id: att.id }
      expect(response).to be_successful
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    let!(:assess_att) { create_assess_att_with_cid_aid(cid, aid, released) }
    it "renders assessment successfully" do
      get :show, params: { course_name: cname, assessment_name: aname, id: assess_att.id }
      expect(response).to be_successful
    end
  end

  shared_examples "show_failure" do |u, login: true, released: true|
    login_as(u) if login
    let!(:cid)  { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    let!(:att) { create_course_att_with_cid(cid, released) }
    it "renders course with failure" do
      get :show, params: { course_name: cname, id: att.id }
      expect(response).not_to be_successful
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    let!(:assess_att) { create_assess_att_with_cid_aid(cid, aid, released) }
    it "renders assessment with failure" do
      get :show, params: { course_name: cname, assessment_name: aname, id: assess_att.id }
      expect(response).not_to be_successful
    end
  end

  shared_examples "show_missing" do |u|
    login_as(u)
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:cname) { Course.find(cid).name }
    it "flashes error for non-existent course attachment" do
      get :show, params: { course_name: cname, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:aname) { Assessment.find(aid).name }
    it "flashes error for non-existent assessment attachment" do
      get :show, params: { course_name: cname, assessment_name: aname, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      it_behaves_like "show_success", get_admin
      it_behaves_like "show_success", get_admin, released: false
      it_behaves_like "show_missing", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "show_success", get_instructor
      it_behaves_like "show_success", get_instructor, released: false
      it_behaves_like "show_missing", get_instructor
    end

    context "when user is Autolab user" do
      it_behaves_like "show_success", get_user
      it_behaves_like "show_failure", get_user, released: false
      it_behaves_like "show_missing", get_user
    end

    context "when user is not logged in" do
      it_behaves_like "show_failure", get_admin, login: false
      it_behaves_like "show_failure", get_admin, login: false, released: false
    end
  end

  # Functionality tests
  # Create
  # Update
  # Destroy
end
