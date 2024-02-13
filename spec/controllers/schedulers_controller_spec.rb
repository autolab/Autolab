require "rails_helper"
require "fileutils"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe SchedulersController, type: :controller do
  render_views

  shared_examples "index_success" do
    it "renders successfully" do
      sign_in(user)
      get :index, params: { course_name: @course.name }
      expect(response).to be_successful
      expect(response.body).to match(/Manage Schedulers/m)
    end
  end

  shared_examples "index_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :index, params: { course_name: @course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Manage Schedulers/m)
    end
  end

  shared_examples "new_success" do
    it "renders successfully" do
      sign_in(user)
      get :new, params: { course_name: @course.name }
      expect(response).to be_successful
      expect(response.body).to match(/New scheduler/m)
    end
  end

  shared_examples "new_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :new, params: { course_name: @course.name }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/New scheduler/m)
    end
  end

  shared_examples "edit_success" do
    it "renders successfully" do
      sign_in(user)
      s = create_scheduler_with_cid(@course.id)
      get :edit, params: { course_name: @course.name, id: s.id }
      expect(response).to be_successful
      expect(response.body).to match(/Editing scheduler/m)
    end
  end

  shared_examples "edit_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      s = create_scheduler_with_cid(@course.id)
      get :edit, params: { course_name: @course.name, id: s.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Editing scheduler/m)
    end
  end

  shared_examples "show_success" do
    it "renders successfully" do
      sign_in(user)
      s = create_scheduler_with_cid(@course.id)
      get :show, params: { course_name: @course.name, id: s.id }
      expect(response).to be_successful
      expect(response.body).to match(/Action:/m)
      expect(response.body).to match(/Interval:/m)
    end
  end

  shared_examples "show_failure" do |login: false|
    it "renders successfully" do
      sign_in(user) if login
      s = create_scheduler_with_cid(@course.id)
      get :show, params: { course_name: @course.name, id: s.id }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Action:/m)
      expect(response.body).not_to match(/Interval:/m)
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
      it_behaves_like "show_failure", login: true do
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
