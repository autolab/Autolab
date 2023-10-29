require "rails_helper"
include ControllerMacros
require_relative "controllers_shared_context"

RSpec.describe UsersController, type: :controller do
  render_views
  shared_examples "index_success" do
    it "renders successfully" do
      sign_in(user)
      get :index
      expect(response).to be_successful
      expect(response.body).to match(/Users List/m)
    end
  end

  shared_examples "index_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :index
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Users List/m)
    end
  end

  shared_examples "new_success" do
    it "renders successfully" do
      sign_in(user)
      get :new
      expect(response).to be_successful
      expect(response.body).to match(/Create New User/m)
    end
  end

  shared_examples "new_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :new
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Create New User/m)
    end
  end

  shared_examples "show_success" do
    it "renders successfully" do
      sign_in(user)
      get :show, params: { id: user.id }
      expect(response).to be_successful
      expect(response.body).to match(/Contact/m)
      expect(response.body).to match(/About/m)
      expect(response.body).to match(/Courses/m)
      expect(response.body).to match(/Private Settings/m)
      expect(response.body).to match(/API Settings/m)
    end
  end

  shared_examples "show_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :show, params: { id: 0 }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Showing user/m)
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

    context "when user is Autolab normal user" do
      it_behaves_like "index_success" do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "index_success", login: false do
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

    context "when user is Autolab normal user" do
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

    context "when user is Autolab normal user" do
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
