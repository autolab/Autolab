require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe AttachmentsController, type: :controller do
  render_views

  ### Render tests ###

  # Index
  shared_examples "index_success" do
    before(:each) { sign_in(u) }
    it "renders course successfully" do
      get :index, params: { course_name: course.name }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(/Course Attachments/m)
    end

    it "renders assessment successfully" do
      get :index, params: { course_name: course.name, assessment_name: assessment.name }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(assessment.name)
      expect(response.body).to match(/Add/m)
    end
  end

  shared_examples "index_failure" do |login: true|
    before(:each) { sign_in(u) if login }
    it "renders course with failure" do
      get :index, params: { course_name: course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(/Course Attachments/m)
    end

    it "renders assessment with failure" do
      get :index, params: { course_name: course.name, assessment_name: assessment.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(assessment.name)
      expect(response.body).not_to match(/Add/m)
    end
  end

  describe "#index" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "index_success"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "index_success"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "index_failure", login: true
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "index_failure", login: false
    end
  end

  # New
  shared_examples "new_success" do
    before(:each) { sign_in(u) }

    it "renders course successfully" do
      get :new, params: { course_name: course.name }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Release at/m)
    end

    it "renders assessment successfully" do
      get :new, params: { course_name: course.name, assessment_name: assessment.name }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(assessment.name)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Release at/m)
    end
  end

  shared_examples "new_failure" do |login: true|
    before(:each) { sign_in(u) if login }

    it "renders course with failure" do
      get :new, params: { course_name: course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Release at/m)
    end

    it "renders assessment with failure" do
      get :new, params: { course_name: course.name, assessment_name: assessment.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(assessment.name)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Release at/m)
    end
  end

  describe "#new" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "new_success"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "new_success"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "new_failure"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "new_failure", login: false
    end
  end

  # Edit
  shared_examples "edit_success" do
    before(:each) { sign_in(u) }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "renders course successfully" do
      get :edit, params: { course_name: course.name, id: att.id }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(att.name)
      expect(response.body).to match(att.mime_type)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Mime type/m)
      expect(response.body).to match(/Release at/m)
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "renders assessment successfully" do
      get :edit,
          params: { course_name: course.name, assessment_name: assessment.name, id: assess_att.id }
      expect(response).to be_successful
      expect(response.body).to match(course.name)
      expect(response.body).to match(assessment.name)
      expect(response.body).to match(assess_att.name)
      expect(response.body).to match(assess_att.mime_type)
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Mime type/m)
      expect(response.body).to match(/Release at/m)
    end
  end

  shared_examples "edit_failure" do |login: true|
    before(:each) { sign_in(u) if login }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "renders course with failure" do
      get :edit, params: { course_name: course.name, id: att.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(att.name)
      expect(response.body).not_to match(att.mime_type)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Mime type/m)
      expect(response.body).not_to match(/Release at/m)
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "renders assessment with failure" do
      get :edit,
          params: { course_name: course.name, assessment_name: assessment.name, id: assess_att.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(course.name)
      expect(response.body).not_to match(assessment.name)
      expect(response.body).not_to match(assess_att.name)
      expect(response.body).not_to match(assess_att.mime_type)
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Mime type/m)
      expect(response.body).not_to match(/Release at/m)
    end
  end

  shared_examples "edit_missing" do
    before(:each) { sign_in(u) }

    it "flashes error for non-existent course attachment" do
      get :edit, params: { course_name: course.name, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end

    it "flashes error for non-existent assessment attachment" do
      get :edit, params: { course_name: course.name, assessment_name: assessment.name, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
  end

  describe "#edit" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "edit_success"
      it_behaves_like "edit_missing"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "edit_success"
      it_behaves_like "edit_missing"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "edit_failure"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "edit_failure", login: false
    end
  end

  # Show
  shared_examples "show_success" do |released: true|
    before(:each) { sign_in(u) }

    let!(:att) { create_course_att_with_cid(course.id, released) }
    it "renders course successfully" do
      get :show, params: { course_name: course.name, id: att.id }
      expect(response).to be_successful
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, released) }
    it "renders assessment successfully" do
      get :show,
          params: { course_name: course.name, assessment_name: assessment.name, id: assess_att.id }
      expect(response).to be_successful
    end
  end

  shared_examples "show_failure" do |login: true, released: true|
    before(:each) { sign_in(u) if login }

    let!(:att) { create_course_att_with_cid(course.id, released) }
    it "renders course with failure" do
      get :show, params: { course_name: course.name, id: att.id }
      expect(response).not_to be_successful
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, released) }
    it "renders assessment with failure" do
      get :show,
          params: { course_name: course.name, assessment_name: assessment.name, id: assess_att.id }
      expect(response).not_to be_successful
    end
  end

  shared_examples "show_missing" do
    before(:each) { sign_in(u) }

    it "flashes error for non-existent course attachment" do
      get :show, params: { course_name: course.name, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end

    it "flashes error for non-existent assessment attachment" do
      get :show, params: { course_name: course.name, assessment_name: assessment.name, id: -1 }
      expect(flash[:error]).to match(/Could not find/)
    end
  end

  describe "#show" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "show_success"
      it_behaves_like "show_success", released: false
      it_behaves_like "show_missing"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "show_success"
      it_behaves_like "show_success", released: false
      it_behaves_like "show_missing"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "show_success"
      it_behaves_like "show_failure", released: false
      it_behaves_like "show_missing"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "show_failure", login: false
      it_behaves_like "show_failure", login: false, released: false
    end
  end

  ### Functionality tests ###

  # Create
  shared_examples "create_success" do
    before(:each) { sign_in(u) }

    let!(:att) { course_att_with_cid(course.id, true) }
    it "creates course attachment successfully" do
      expect do
        post :create, params: { course_name: course.name, attachment: att }
        expect(flash[:success]).to match(/Attachment created/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_path(course))
      end.to change(Attachment, :count).by(1)
    end

    let!(:assess_att) { assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "creates assessment attachment successfully" do
      expect do
        post :create,
             params: { course_name: course.name, assessment_name: assessment.name,
                       attachment: assess_att }
        expect(flash[:success]).to match(/Attachment created/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_assessment_path(course, assessment))
      end.to change(Attachment, :count).by(1)
    end
  end

  shared_examples "create_error" do
    before(:each) { sign_in(u) }

    let!(:att) { course_att_with_cid(course.id, true).except(:name, :file, :release_at) }
    it "fails to create course attachment with missing name or file" do
      expect do
        post :create, params: { course_name: course.name, attachment: att }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(flash[:error]).to match(/Filename can't be blank/)
        expect(flash[:error]).to match(/Release at can't be blank/)
        expect(response).to redirect_to(new_course_attachment_path(course))
      end.not_to change(Attachment, :count)
    end

    let!(:assess_att) {
      assess_att_with_cid_aid(course.id, assessment.id, true).except(:name, :file, :release_at)
    }
    it "fails to create assessment attachment with missing name or file" do
      expect do
        post :create,
             params: { course_name: course.name, assessment_name: assessment.name,
                       attachment: assess_att }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(flash[:error]).to match(/Filename can't be blank/)
        expect(flash[:error]).to match(/Release at can't be blank/)
        expect(response).to redirect_to(new_course_assessment_attachment_path(course, assessment))
      end.not_to change(Attachment, :count)
    end
  end

  shared_examples "create_failure" do |login: true|
    before(:each) { sign_in(u) if login }

    let!(:att) { course_att_with_cid(course.id, true) }
    it "fails to create course attachment" do
      expect do
        post :create, params: { course_name: course.name, attachment: att }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end

    let!(:assess_att) { assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "fails to create assessment attachment" do
      expect do
        post :create,
             params: { course_name: course.name, assessment_name: assessment.name,
                       attachment: assess_att }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end
  end

  describe "#create" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "create_success"
      it_behaves_like "create_error"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "create_success"
      it_behaves_like "create_error"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "create_failure"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "create_failure", login: false
    end
  end

  shared_examples "update_success" do
    before(:each) { sign_in(u) }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "updates course attachment successfully" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, id: att.id, attachment: {
          name: "new_name",
          mime_type: "new_mime_type",
          release_at: release_time,
        } }
        expect(flash[:success]).to match(/Attachment updated/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_path(course))
      end.not_to change(Attachment, :count)
      att.reload
      expect(att.name).to eq("new_name")
      expect(att.mime_type).to eq("new_mime_type")
      expect(att.release_at).to be_within(1.second).of release_time
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "updates assessment attachment successfully" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, assessment_name: assessment.name,
                                id: assess_att.id,
                                attachment: {
                                  name: "new_name",
                                  mime_type: "new_mime_type",
                                  release_at: release_time,
                                } }
        expect(flash[:success]).to match(/Attachment updated/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_assessment_path(course, assessment))
      end.not_to change(Attachment, :count)
      assess_att.reload
      expect(assess_att.name).to eq("new_name")
      expect(assess_att.mime_type).to eq("new_mime_type")
      expect(assess_att.release_at).to be_within(1.second).of release_time
    end
  end

  shared_examples "update_error" do
    before(:each) { sign_in(u) }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "fails to update course attachment with missing name" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, id: att.id, attachment: {
          name: "",
          mime_type: "new_mime_type",
          release_at: release_time,
        } }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(response).to redirect_to(edit_course_attachment_path(course, att))
      end.not_to change(Attachment, :count)
      att.reload
      expect(att.name).not_to eq("")
      expect(att.mime_type).not_to eq("new_mime_type")
      expect(att.release_at).not_to be_within(1.second).of release_time
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "fails to update assessment attachment with missing name" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, assessment_name: assessment.name,
                                id: assess_att.id,
                                attachment: {
                                  name: "",
                                  mime_type: "new_mime_type",
                                  release_at: release_time,
                                } }
        expect(flash[:success]).to be_nil
        expect(flash[:error]).to match(/Name can't be blank/)
        expect(response).to redirect_to(edit_course_assessment_attachment_path(course, assessment,
                                                                               assess_att))
      end.not_to change(Attachment, :count)
      assess_att.reload
      expect(assess_att.name).not_to eq("")
      expect(assess_att.mime_type).not_to eq("new_mime_type")
      expect(assess_att.release_at).not_to be_within(1.second).of release_time
    end
  end

  shared_examples "update_failure" do |login: true|
    before(:each) { sign_in(u) if login }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "fails to update course attachment" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, id: att.id, attachment: {
          name: "new_name",
          mime_type: "new_mime_type",
          release_at: release_time,
        } }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
      att.reload
      expect(att.name).not_to eq("new_name")
      expect(att.mime_type).not_to eq("new_mime_type")
      expect(att.release_at).not_to be_within(1.second).of release_time
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "fails to update assessment attachment" do
      release_time = Time.current - 1.day
      expect do
        post :update, params: { course_name: course.name, assessment_name: assessment.name,
                                id: assess_att.id,
                                attachment: {
                                  name: "new_name",
                                  mime_type: "new_mime_type",
                                  release_at: release_time,
                                } }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
      assess_att.reload
      expect(assess_att.name).not_to eq("new_name")
      expect(assess_att.mime_type).not_to eq("new_mime_type")
      expect(assess_att.release_at).not_to be_within(1.second).of release_time
    end
  end

  # Update
  describe "#update" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "update_success"
      it_behaves_like "update_error"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "update_success"
      it_behaves_like "update_error"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "update_failure"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "update_failure", login: false
    end
  end

  # Destroy
  shared_examples "destroy_success" do
    before(:each) { sign_in(u) }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "destroys course attachment successfully" do
      expect do
        delete :destroy, params: { course_name: course.name, id: att.id }
        expect(flash[:success]).to match(/Attachment deleted/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_path(course))
      end.to change(Attachment, :count).by(-1)
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "destroys assessment attachment successfully" do
      expect do
        delete :destroy,
               params: { course_name: course.name, assessment_name: assessment.name,
                         id: assess_att.id }
        expect(flash[:success]).to match(/Attachment deleted/)
        expect(flash[:error]).to be_nil
        expect(response).to redirect_to(course_assessment_path(course, assessment))
      end.to change(Attachment, :count).by(-1)
    end
  end

  shared_examples "destroy_failure" do |login: true|
    before(:each) { sign_in(u) if login }

    let!(:att) { create_course_att_with_cid(course.id, true) }
    it "fails to destroy course attachment" do
      expect do
        delete :destroy, params: { course_name: course.name, id: att.id }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end

    let!(:assess_att) { create_assess_att_with_cid_aid(course.id, assessment.id, true) }
    it "fails to destroy assessment attachment" do
      expect do
        delete :destroy,
               params: { course_name: course.name, assessment_name: assessment.name,
                         id: assess_att.id }
        expect(flash[:success]).to be_nil
      end.not_to change(Attachment, :count)
    end
  end

  describe "#destroy" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:u) { admin_user }
      it_behaves_like "destroy_success"
    end

    context "when user is Autolab instructor" do
      let!(:u) { instructor_user }
      it_behaves_like "destroy_success"
    end

    context "when user is Autolab user" do
      let!(:u) { student_user }
      it_behaves_like "destroy_failure"
    end

    context "when user is not logged in" do
      let!(:u) { admin_user }
      it_behaves_like "destroy_failure", login: false
    end
  end
end
