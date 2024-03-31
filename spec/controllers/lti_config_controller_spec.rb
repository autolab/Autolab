require "rails_helper"
require_relative "controllers_shared_context"

RSpec.describe LtiConfigController, type: :controller do
  render_views

  before(:all) do
    @lti_config_hash =
      YAML.safe_load(
        File.read("#{Rails.configuration.config_location}/lti_config_template.yml")
      )
    @lti_tool_jwk_file =
      Rack::Test::UploadedFile.new(
        "#{Rails.configuration.config_location}/lti_tool_jwk_template.json"
      )
    @lti_platform_jwk_file =
      Rack::Test::UploadedFile.new(
        "#{Rails.configuration.config_location}/lti_platform_jwk_template.json"
      )
  end

  after(:each) do
    if File.exist?("#{Rails.configuration.config_location}/lti_config.yml")
      File.delete("#{Rails.configuration.config_location}/lti_config.yml")
    end
    if File.exist?("#{Rails.configuration.config_location}/lti_tool_jwk.json")
      File.delete("#{Rails.configuration.config_location}/lti_tool_jwk.json")
    end
    if File.exist?("#{Rails.configuration.config_location}/lti_platform_jwk.json")
      File.delete("#{Rails.configuration.config_location}/lti_platform_jwk.json")
    end
  end

  describe "#update_config" do
    include_context "controllers shared context"
    context "when user is Autolab admin" do
      let!(:user_id) do
        @admin_user
      end
      before(:each) do
        sign_in(user_id)
      end
      it "rejects empty POST" do
        post :update_config, params: {}
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
      end
      it "rejects valid params but no file" do
        post :update_config, params: {
          iss: @lti_config_hash["iss"],
          developer_key: @lti_config_hash["developer_key"],
          auth_url: @lti_config_hash['auth_url'],
          platform_public_jwks_url: @lti_config_hash['platform_public_jwks_url'],
          oauth2_access_token_url: @lti_config_hash['oauth2_access_token_url']
        }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(flash[:error]).to match(/No tool JWK JSON file was uploaded/m)
      end
      it "rejects no jwk json or url uploaded" do
        post :update_config, params: {
          iss: @lti_config_hash["iss"], developer_key: @lti_config_hash["developer_key"],
          auth_url: @lti_config_hash['auth_url'], platform_public_jwks_url: "",
          oauth2_access_token_url: @lti_config_hash['oauth2_access_token_url'],
          tool_jwk: @lti_tool_jwk_file
        }
        expect(response).to have_http_status(302)
        expect(flash[:error]).to be_present
        expect(
          flash[:error]
        ).to match(
          /No platform JWK JSON file or URL was uploaded. Please specify one or the other/m
        )
      end
      it "accepts valid POST" do
        post :update_config, params: {
          iss: @lti_config_hash["iss"],
          developer_key: @lti_config_hash["developer_key"],
          auth_url: @lti_config_hash['auth_url'],
          platform_public_jwks_url: @lti_config_hash['platform_public_jwks_url'],
          oauth2_access_token_url: @lti_config_hash['oauth2_access_token_url'],
          tool_jwk: @lti_tool_jwk_file
        }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end
      it "accepts JWK platform file" do
        post :update_config, params: {
          iss: @lti_config_hash["iss"], developer_key: @lti_config_hash["developer_key"],
          auth_url: @lti_config_hash['auth_url'], platform_public_jwks_url: "",
          platform_public_jwk_json: @lti_platform_jwk_file,
          tool_jwk: @lti_tool_jwk_file,
          oauth2_access_token_url: @lti_config_hash['oauth2_access_token_url']
        }
        expect(response).to have_http_status(302)
        expect(flash[:success]).to be_present
      end
    end
  end
end
