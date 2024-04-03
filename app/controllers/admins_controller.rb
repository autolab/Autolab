##
# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController
  skip_before_action :set_course

  action_auth_level :email_instructors, :administrator
  def email_instructors
    @users = User.select(:email).joins(:course_user_data).distinct
                 .where(course_user_data: { instructor: true })
                 .order('email ASC')

    return unless request.post?

    @email = CourseMailer.system_announcement(
      params[:from],
      make_dlist(@cuds),
      params[:subject],
      params[:body]
    )
    @email.deliver
  end

  action_auth_level :github_integration, :administrator
  def github_integration
    @github_integration = GithubIntegration.check_github_authorization
  end

  action_auth_level :clear_cache, :administrator
  def clear_cache
    Rails.cache.cleanup
    flash[:success] = "Cache Cleared"
    redirect_back(fallback_location: root_path)
  end

  action_auth_level :autolab_config, :administrator
  def autolab_config
    @github_integration = GithubIntegration.check_github_authorization

    if File.size?("#{Rails.configuration.config_location}/lti_config.yml")
      @lti_config_hash =
        YAML.safe_load(File.read("#{Rails.configuration.config_location}/lti_config.yml"))
    end

    if Rails.cache.exist?(:tmp_smtp_config)
      @smtp_config_hash = Rails.cache.read(:tmp_smtp_config)
      Rails.cache.delete(:tmp_smtp_config)
    elsif File.size?("#{Rails.configuration.config_location}/smtp_config.yml")
      @smtp_config_hash =
        YAML.safe_load(File.read("#{Rails.configuration.config_location}/smtp_config.yml"))
      @smtp_config_hash.symbolize_keys!
    end

    @github_config_hash = {
      client_id: Rails.configuration&.x&.github&.client_id || "",
      client_secret: Rails.configuration&.x&.github&.client_secret || ""
    }

    @configured_oauth_providers = OauthConfigController.get_oauth_providers
  end
end
