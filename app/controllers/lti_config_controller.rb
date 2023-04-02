require 'psych'

class LtiConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_config, :administrator
  def update_config
    required_params = %w[iss developer_key auth_url oauth2_access_token_url]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :lti)) && return
      end
    end

    # create hash from form
    yaml_hash = {
      iss: params['iss'],
      developer_key: params['developer_key'],
      auth_url: params['auth_url'],
      platform_public_jwks_url: params['platform_public_jwks_url'],
      oauth2_access_token_url: params['oauth2_access_token_url']
    }
    uploaded_tool_jwk_file = params['tool_jwk']
    # Ensure user uploaded private JWK for config, or it already exists
    if !File.exist?("#{Rails.configuration.config_location}/lti_tool_jwk.json") &&
       uploaded_tool_jwk_file.nil?
      flash[:error] = "No tool JWK JSON file was uploaded"
      redirect_to(autolab_config_admin_path(active: :lti)) && return
    end
    # Ensure either plaform has a jwk file associated with it or URL to public JWKs
    uploaded_platform_public_jwk_file = params['platform_public_jwk_json']
    if uploaded_platform_public_jwk_file.nil? && yaml_hash[:platform_public_jwks_url].blank?
      flash[:error] =
        "No platform JWK JSON file or URL was uploaded. Please specify one or the other"
      redirect_to(autolab_config_admin_path(active: :lti)) && return
    end
    # write text parameters to config yml
    File.open("#{Rails.configuration.config_location}/lti_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end
    # write private key to separate file if it was uploaded
    unless uploaded_tool_jwk_file.nil?
      File.open("#{Rails.configuration.config_location}/lti_tool_jwk.json", "w") do |file|
        file.write(uploaded_tool_jwk_file.read)
      end
    end
    # write platform public key to separate file, if it exists
    unless uploaded_platform_public_jwk_file.nil?
      File.open("#{Rails.configuration.config_location}/lti_platform_jwk.json", "w") do |file|
        file.write(uploaded_platform_public_jwk_file.read)
      end
    end

    flash[:success] = "LTI configuration was successfully updated"
    redirect_to(autolab_config_admin_path(active: :lti)) && return
  end
end
