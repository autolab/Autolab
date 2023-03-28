require "rails_helper"
require_relative "controllers_shared_context"

RSpec.describe AdminsController, type: :controller do
  render_views

  shared_examples "email_instructors_success" do
    it "renders successfully" do
      sign_in(user)
      get :email_instructors
      expect(response).to be_successful
      expect(response.body).to match(/From:/m)
      expect(response.body).to match(/Subject:/m)
    end
  end

  shared_examples "email_instructors_failure" do |login: false|
    it "renders with failure" do
      sign_in(user) if login
      get :email_instructors
      expect(response).not_to be_successful
      expect(response.body).not_to match(/From:/m)
      expect(response.body).not_to match(/Subject:/m)
    end
  end

  describe "#email_instructors" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      it_behaves_like "email_instructors_success" do
        let!(:user) { admin_user }
      end
    end

    context "when user is Autolab normal user" do
      it_behaves_like "email_instructors_failure", login: true do
        let!(:user) { student_user }
      end
    end

    context "when user is not logged in" do
      it_behaves_like "email_instructors_failure", login: false do
        let!(:user) { student_user }
      end
    end
  end
end
