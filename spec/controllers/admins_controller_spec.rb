require "rails_helper"

RSpec.describe AdminsController, type: :controller do
  render_views

  describe "#email_instructors" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :email_instructors
        expect(response).to be_successful
        expect(response.body).to match(/From:/m)
        expect(response.body).to match(/Subject:/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders with failure" do
        get :email_instructors
        expect(response).not_to be_successful
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :email_instructors
        expect(response).not_to be_successful
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end
  end
end
