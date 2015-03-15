require 'rails_helper'

RSpec.describe AdminsController, :type => :controller do
  
  render_views

  describe "#show" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :show
        expect(response).to be_success
        expect(response.body).to match(/Admin Autolab/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders with failure" do
        get :show
        expect(response).not_to be_success
        expect(response.body).not_to match(/Admin Autolab/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :show
        expect(response).not_to be_success
        expect(response.body).not_to match(/Admin Autolab/m)
      end
    end
  end

  describe "#emailInstructors" do
    context "when user is Autolab admin" do
      login_admin
      it "renders successfully" do
        get :emailInstructors
        expect(response).to be_success
        expect(response.body).to match(/From:/m)
        expect(response.body).to match(/Subject:/m)
      end
    end

    context "when user is Autolab normal user" do
      login_user
      it "renders with failure" do
        get :emailInstructors
        expect(response).not_to be_success
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end

    context "when user is not logged in" do
      it "renders with failure" do
        get :emailInstructors
        expect(response).not_to be_success
        expect(response.body).not_to match(/From:/m)
        expect(response.body).not_to match(/Subject:/m)
      end
    end
  end
end
