require 'rails_helper'

RSpec.describe Api::V1::UserController, :type => :controller do
  describe 'GET #show' do
    user = get_user
    let!(:application) { Doorkeeper::Application.create! :name => "TestApp", :redirect_uri => "https://example.com", :scopes => "user_info" }
    let!(:token) { Doorkeeper::AccessToken.create! :application_id => application.id, :resource_owner_id => user.id, :scopes => "user_info" }

    it 'returns correct user email' do
      get :show, :access_token => token.token
      expect(response.response_code).to eq(200)
      msg = JSON.parse(response.body)
      expect(msg["email"]).to eq(user.email)
    end
  end
end