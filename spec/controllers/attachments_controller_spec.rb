require "rails_helper"
include ControllerMacros

RSpec.describe AttachmentsController, type: :controller do
  render_views

  ### Render tests ###

  # Index
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

  # New
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

  # Edit
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

  # Show
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

  ### Functionality tests ###

  # Create
  shared_examples "create_success" do |u|
    login_as(u)
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:course) { Course.find(cid) }
    let!(:cname) { course.name }
    let!(:att) { course_att_with_cid(cid, true) }
    it "creates course attachment successfully" do
      expect do
        post :create, params: { course_name: cname, attachment: att }
        expect(flash[:success]).to match(/Attachment created/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_path(course))
      end.to change(Attachment, :count).by(1)
    end

    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:assessment) { Assessment.find(aid) }
    let!(:aname) { assessment.name }
    let!(:assess_att) { assess_att_with_cid_aid(cid, aid, true) }
    it "creates assessment attachment successfully" do
      expect do
        post :create, params: { course_name: cname, assessment_name: aname, attachment: assess_att }
        expect(flash[:success]).to match(/Attachment created/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_assessment_path(course, assessment))
      end.to change(Attachment, :count).by(1)
    end
  end

  shared_examples "create_error" do |u|
    login_as(u)
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:course) { Course.find(cid) }
    let!(:cname) { course.name }
    let!(:att) { course_att_with_cid(cid, true).except(:name, :file) }
    it "fails to create course attachment with missing name or file" do
      expect do
        post :create, params: { course_name: cname, attachment: att }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(flash[:error]).to match(/Filename can't be blank/)
        expect(response).to redirect_to(new_course_attachment_path(course))
      end.not_to change(Attachment, :count)
    end

    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:assessment) { Assessment.find(aid) }
    let!(:aname) { assessment.name }
    let!(:assess_att) { assess_att_with_cid_aid(cid, aid, true).except(:name, :file) }
    it "fails to create assessment attachment with missing name or file" do
      expect do
        post :create, params: { course_name: cname, assessment_name: aname, attachment: assess_att }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(flash[:error]).to match(/Filename can't be blank/)
        expect(response).to redirect_to(new_course_assessment_attachment_path(course, assessment))
      end.not_to change(Attachment, :count)
    end
  end

  shared_examples "create_failure" do |u, login: true|
    login_as(u) if login
    let!(:cid) { get_course_id_by_uid(u.id) }
    let!(:course) { Course.find(cid) }
    let!(:cname) { course.name }
    let!(:att) { course_att_with_cid(cid, true) }
    it "fails to create course attachment" do
      expect do
        post :create, params: { course_name: cname, attachment: att }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end

    let!(:aid) { get_first_aid_by_cid(cid) }
    let!(:assessment) { Assessment.find(aid) }
    let!(:aname) { assessment.name }
    let!(:assess_att) { assess_att_with_cid_aid(cid, aid, true) }
    it "fails to create assessment attachment" do
      expect do
        post :create, params: { course_name: cname, assessment_name: aname, attachment: assess_att }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end
  end

  describe "#create" do
    context "when user is Autolab admin" do
      it_behaves_like "create_success", get_admin
      it_behaves_like "create_error", get_admin
    end

    context "when user is Autolab instructor" do
      it_behaves_like "create_success", get_instructor
      it_behaves_like "create_error", get_instructor
    end

    context "when user is Autolab user" do
      it_behaves_like "create_failure", get_user
    end

    context "when user is not logged in" do
      it_behaves_like "create_failure", get_admin, login: false
    end
  end

  # Update

  # Destroy
end
