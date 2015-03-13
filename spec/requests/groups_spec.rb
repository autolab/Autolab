require "rails_helper"

RSpec.describe "Groups", type: :request do
  describe "GET /groups" do
    it "works! (now write some real specs)" do
      get groups_path
      expect(response).to have_http_status(200)
    end
  end
end
