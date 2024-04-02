require 'action_mailer'
require 'tempfile'
require 'psych'

class OauthConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_oauth_config, :administrator
  def update_oauth_config
    required_params = %w[provider client_id client_secret]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :oauth)) && return
      end
    end

    yaml_hash = {}
    if File.exist?("#{Rails.configuration.config_location}/oauth_config.yml")
      yaml_hash = YAML.safe_load(
        File.read("#{Rails.configuration.config_location}/oauth_config.yml")
      )
    end

    yaml_hash[params[:provider]] = {
      client_id: params[:client_id],
      client_secret: params[:client_secret]
    }

    Rails.cache.write(:oauth_config, yaml_hash.deep_symbolize_keys!)

    File.open("#{Rails.configuration.config_location}/oauth_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end

    flash[:success] = "OAuth Config successfully updated"

    redirect_to autolab_config_admin_path(active: :oauth)
  end

  def self.get_oauth_providers
    Rails.cache.fetch(:oauth_providers) do
      return [] unless File.exist?("#{Rails.configuration.config_location}/oauth_config.yml")

      config_hash = YAML.safe_load(
        File.read("#{Rails.configuration.config_location}/oauth_config.yml")
      ).deep_symbolize_keys!

      providers = []
      config_hash.each do |provider, _|
        providers.append provider
      end

      providers
    end
  end

  def self.get_oauth_credentials(provider)
    oauth_config = Rails.cache.fetch(:oauth_config) do
      return {} unless File.exist?("#{Rails.configuration.config_location}/oauth_config.yml")

      YAML.safe_load(
        File.read("#{Rails.configuration.config_location}/oauth_config.yml")
      ).deep_symbolize_keys!
    end

    return {} unless oauth_config.key? provider

    oauth_config[provider]
  end
end
