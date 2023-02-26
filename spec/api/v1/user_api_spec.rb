require 'rails_helper'
require_relative "api_shared_context"

RSpec.describe Api::V1::UserController, type: :controller do
  describe 'GET #show' do
    include_context "api shared context"

    it 'returns correct user email' do
      get :show, params: { access_token: token.token }
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg["email"]).to eq(user.email)
    end
  end
end
