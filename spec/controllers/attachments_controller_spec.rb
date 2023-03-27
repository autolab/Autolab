require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe AttachmentsController, type: :controller do
  render_views

  shared_examples "index_success" do
    it "renders successfully" do
      sign_in(user)
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      get :index, params: { course_name: cname }
      expect(response).to be_successful
      expect(response.body).to match(/Course Attachments/m)
    end
  end

  shared_examples "index_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      get :index, params: { course_name: cname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Course Attachments/m)
    end
  end

  shared_examples "new_success" do
    it "renders successfully" do
      sign_in(user)
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      get :new, params: { course_name: cname }
      expect(response).to be_successful
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Released/m)
    end
  end

  shared_examples "new_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      get :new, params: { course_name: cname }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Released/m)
    end
  end

  shared_examples "edit_success" do
    it "renders successfully" do
      sign_in(user)
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      # TODO: replace with factory (this code will become redundant)
      # based on develop branch changes to attachments
      att = create_course_att_with_cid(cid)
      get :edit, params: { course_name: cname, id: att.id }
      expect(response).to be_successful
      expect(response.body).to match(/Name/m)
      expect(response.body).to match(/Released/m)
    end
  end

  shared_examples "edit_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      att = create_course_att_with_cid(cid)
      get :edit, params: { course_name: cname, id: att.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Name/m)
      expect(response.body).not_to match(/Released/m)
    end
  end

  shared_examples "show_success" do
    it "renders successfully" do
      sign_in(user)
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      att = create_course_att_with_cid(cid)
      get :show, params: { course_name: cname, id: att.id }
      expect(response).to be_successful
    end
  end

  shared_examples "show_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      cid = get_first_cid_by_uid(user.id)
      cname = Course.find(cid).name
      att = create_course_att_with_cid(cid)
      get :show, params: { course_name: cname, id: att.id }
      expect(response).not_to be_successful
    end
  end

  describe "#index" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "index_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "index_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "index_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "index_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "#new" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "new_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "new_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "new_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "new_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "#edit" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "edit_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "edit_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "edit_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "edit_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end

  describe "#show" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "show_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab instructor" do
      it_behaves_like "show_success" do
        let!(:user) { instructor_user }
      end
    end

    context "when user is Autolab user" do
      it_behaves_like "show_success" do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "show_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end
end
