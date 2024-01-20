require 'rails_helper'
require_relative "api_shared_context"

RSpec.describe Oauth::DeviceFlowController, type: :controller do
  describe 'GET #init' do
    include_context "api shared context"

    it 'returns a valid device_code and user_code pair' do
      get :init, params: { client_id: df_application.uid }
      expect(response.response_code).to eq(200)

      expect(msg).to have_key("device_code")
      expect(msg).to have_key("user_code")

      req = OauthDeviceFlowRequest.find_by(device_code: msg["device_code"])
      expect(req.user_code).to eq(msg["user_code"])
    end

    it 'does not allow invalid client_id' do
      get :init, params: { client_id: df_application.uid.length.times.map {
                                        rand(65..90).chr
                                      }.join }
      expect(response.response_code).to eq(400)
    end

    it 'does not allow missing client_id' do
      get :init
      expect(response.response_code).to eq(400)
    end
  end

  describe 'GET #authorize' do
    include_context "api shared context"

    context 'when given the right params' do
      # set up the request
      before(:each) do
        @req = OauthDeviceFlowRequest.create_request(df_application)
        expect(@req).not_to be_nil
      end

      it 'returns pending when not resolved' do
        get :authorize, params: { client_id: df_application.uid, device_code: @req.device_code }
        expect(response.response_code).to eq(400)
        expect(msg["error"]).to eq("authorization_pending")
      end

      it 'returns denied when access denied' do
        @req.deny_request(:user)
        device_code = @req.device_code

        get :authorize, params: { client_id: df_application.uid, device_code: }
        expect(response.response_code).to eq(400)
        expect(msg["error"]).to include("denied")

        # the request should have been deleted from db
        prev_req = OauthDeviceFlowRequest.find_by(device_code:)
        expect(prev_req).to be_nil
      end

      it 'returns the access code when granted access' do
        access_code = 32.times.map { rand(65..90).chr }.join
        @req.grant_request(:user, access_code)
        device_code = @req.device_code

        get :authorize, params: { client_id: df_application.uid, device_code: }
        expect(response.response_code).to eq(200)
        expect(msg).to have_key("code")
        expect(msg["code"]).to eq(access_code)

        # the request should have been deleted from db
        prev_req = OauthDeviceFlowRequest.find_by(device_code:)
        expect(prev_req).to be_nil
      end
    end

    it 'does not allow invalid device_code' do
      get :authorize, params: { client_id: df_application.uid, device_code: 32.times.map {
                                                                              rand(65..90).chr
                                                                            }.join }
      expect(response.response_code).to eq(400)
    end

    it 'does not allow missing device_code' do
      get :authorize, params: { client_id: df_application.uid }
      expect(response.response_code).to eq(400)
    end

    it 'does not allow invalid client_id' do
      get :authorize, params: { client_id: df_application.uid.length.times.map {
                                             rand(65..90).chr
                                           }.join }
      expect(response.response_code).to eq(400)
    end

    it 'does not allow missing client_id' do
      get :authorize
      expect(response.response_code).to eq(400)
    end
  end
end
