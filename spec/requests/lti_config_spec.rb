require 'rails_helper'

RSpec.describe "LtiConfigs", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/lti_config/index"
      expect(response).to have_http_status(:success)
    end
  end

end
