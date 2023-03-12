require "rails_helper"

RSpec.describe AdminsController, type: :controller do
  render_views
  shared_examples "email_instructors_success" do
    before(:each) do
      sign_in(user)
    end
    it "renders successfully" do
      get :email_instructors
      expect(response).to be_successful
      expect(response.body).to match(/From:/m)
      expect(response.body).to match(/Subject:/m)
    end
  end
  shared_examples "email_instructors_failure" do |login: false|
    before(:each) do
      sign_in(user) if login
    end
    it "renders with failure" do
      get :email_instructors
      expect(response).not_to be_successful
      expect(response.body).not_to match(/From:/m)
      expect(response.body).not_to match(/Subject:/m)
    end
  end
  describe "#email_instructors" do
    context "when user is Autolab admin" do
      it_behaves_like "email_instructors_success" do
        let!(:user) do
          create_course_with_users
          @admin_user
        end
      end
    end

    context "when user is Autolab normal user" do
      it_behaves_like "email_instructors_failure", login: true do
        let!(:user) do
          create_course_with_users
          @students.first
        end
      end
    end

    context "when user is not logged in" do
      it_behaves_like "email_instructors_failure", login: false do
        let!(:user) do
          create_course_with_users
          @students.first
        end
      end
    end
  end
end
