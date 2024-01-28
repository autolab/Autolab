require "rails_helper"

RSpec.describe HomeController, type: :controller do
  render_views

  describe "#contact" do
    it "renders successfully" do
      get :contact
      expect(response).to be_successful
      expect(response.body).to match(/Contact Autolab/m)
    end
  end

  describe "#developer_login" do
    it "renders successfully" do
      get :developer_login
      expect(response).to be_successful
      expect(response.body).to match(/Development Autolab/m)
    end
  end

  describe "#error_404" do
    it "renders successfully" do
      get :error_404
      expect(response).to be_successful
      expect(response.body).to match(/Not found/m)
    end
  end

  describe "#error_500" do
    it "renders successfully" do
      get :error_500
      expect(response).to be_successful
      expect(response.body).to match(/Internal error/m)
    end
  end

  describe "#no_user" do
    it "renders successfully" do
      get :no_user
      expect(response).to be_successful
      expect(
        response.body
      ).to match(/We noticed that you're not currently associated with any courses/m)
    end
  end
end
