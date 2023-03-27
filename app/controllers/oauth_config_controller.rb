require 'action_mailer'
require 'tempfile'
require 'psych'

class OauthConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_google_oauth_config, :administrator
  def update_google_oauth_config
    required_params = %w[client_id client_secret]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :oauth)) && return
      end
    end

    yaml_hash = {
      client_id: params[:client_id],
      client_secret: params[:client_secret]
    }

    Devise.omniauth :google_oauth2, params[:client_id], params[:client_secret]

    File.open("#{Rails.configuration.config_location}/google_oauth_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end

    flash[:success] = "Google OAuth configuration was successfully updated"
    redirect_to autolab_config_admin_path(active: :oauth)
  end
end
