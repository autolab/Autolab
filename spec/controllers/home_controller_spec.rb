require "rails_helper"

RSpec.describe HomeController, type: :controller do
  render_views

  describe "#contact" do
    it "renders successfully" do
      get :contact
      expect(response).to be_success
      expect(response.body).to match(/Contact Autolab/m)
    end
  end

  describe "#developer_login" do
    it "renders successfully" do
      get :developer_login
      expect(response).to be_success
      expect(response.body).to match(/Development Autolab/m)
    end
  end

  describe "#error" do
    it "renders successfully" do
      get :error
      expect(response).to be_success
      expect(response.body).to match(/Internal error/m)
    end
  end

  describe "#no_user" do
    it "renders successfully" do
      get :no_user
      expect(response).to be_success
      expect(response.body).to match(/didn't find your account/m)
    end
  end
end
