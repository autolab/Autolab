require 'psych'

class LtiConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :index, :administrator
  def index
    if File.exist?("config/lti_config.yml")
      @lti_config_hash = YAML.safe_load(File.read("config/lti_config.yml"))
    end
    puts(@lti_config_hash)
  end
  action_auth_level :update_config, :administrator
  def update_config
    # create hash from form
    yaml_hash = {
      iss: params['iss'],
      developer_key: params['developer_key'],
      auth_url: params['auth_url'],
      platform_public_jwks: params['platform_public_jwks'],
      oauth2_access_token_url: params['oauth2_access_token_url']
    }
    uploaded_file = params['tool_jwk']
    if uploaded_file.nil?
      flash[:error] = "No JSON file was uploaded"
      redirect_to(lti_config_index_path) && return
    end
    # write text parameters to config yml
    File.open("config/lti_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end
    # write private key to separate file
    File.open("config/lti_tool_jwk.json", "w") do |file|
      file.write(uploaded_file.read)
    end
    flash[:success] = "LTI configuration was successfully updated"
    redirect_to(lti_config_index_path) && return
  end
end
