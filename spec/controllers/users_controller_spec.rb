require "rails_helper"
include ControllerMacros

RSpec.describe UsersController, type: :controller do
  render_views
  shared_examples "index_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      get :index
      expect(response).to be_successful
      expect(response.body).to match(/Users List/m)
    end
  end

  shared_examples "index_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :index
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Users List/m)
    end
  end

  shared_examples "new_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      get :new
      expect(response).to be_successful
      expect(response.body).to match(/New user/m)
    end
  end

  shared_examples "new_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :new
      expect(response).not_to be_successful
      expect(response.body).not_to match(/New user/m)
    end
  end

  shared_examples "show_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
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
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :show, params: { id: 0 }
      expect(response).not_to be_successful
      expect(response.body).not_to match(/Showing user/m)
    end
  end

  describe "#index" do
    context "when user is Autolab admin" do
      it_behaves_like "index_success" do
        let!(:user) do
          create_users
          @admin_user
        end
      end
    end
    context "when user is Autolab instructor" do
      it_behaves_like "index_success" do
        let!(:user) do
          # necessary to use create_course_with_users since
          # otherwise instructor user won't be instructor of any classes!
          create_course_with_users
          @instructor_user
        end
      end
    end
    context "when user is Autolab normal user" do
      it_behaves_like "index_success" do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
    context "when user is not logged in" do
      it_behaves_like "index_success", login: false do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
  end

  describe "#new" do
    context "when user is Autolab admin" do
      it_behaves_like "new_success" do
        let!(:user) do
          create_users
          @admin_user
        end
      end
    end
    context "when user is Autolab instructor" do
      it_behaves_like "new_success" do
        let!(:user) do
          create_course_with_users
          @instructor_user
        end
      end
    end
    context "when user is Autolab normal user" do
      it_behaves_like "new_failure", login: true do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
    context "when user is not logged in" do
      it_behaves_like "new_failure", login: false do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
  end

  describe "#show" do
    context "when user is Autolab admin" do
      it_behaves_like "show_success" do
        let!(:user) do
          create_users
          @admin_user
        end
      end
    end
    context "when user is Autolab instructor" do
      it_behaves_like "show_success" do
        let!(:user) do
          create_course_with_users
          @instructor_user
        end
      end
    end
    context "when user is Autolab normal user" do
      it_behaves_like "show_success" do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
    context "when user is not logged in" do
      it_behaves_like "show_failure", login: false do
        let!(:user) do
          create_users
          @students.first
        end
      end
    end
  end
end
