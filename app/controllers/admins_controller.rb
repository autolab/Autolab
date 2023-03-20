##
# this controller contains methods for system-wise
# admin functionality
class AdminsController < ApplicationController
  rescue_from ActionView::MissingTemplate do |_exception|
    redirect_to("/home/error_404")
  end

  skip_before_action :set_course

  action_auth_level :email_instructors, :administrator
  def email_instructors
    @cuds = CourseUserDatum.select(:user_id).distinct.joins(:course).joins(:user)
                           .where(instructor: true)
                           .order("users.email ASC")

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

    if File.exist?("#{Rails.configuration.config_location}/lti_config.yml")
      @lti_config_hash =
        YAML.safe_load(File.read("#{Rails.configuration.config_location}/lti_config.yml"))
    end

    if params[:tmp_smtp_config].present? && File.exist?(params[:tmp_smtp_config])
      @smtp_config_hash = YAML.safe_load(File.read(params[:tmp_smtp_config]))
      File.delete params[:tmp_smtp_config]
    elsif File.exist?("#{Rails.configuration.config_location}/smtp_config.yml")
      @smtp_config_hash =
        YAML.safe_load(File.read("#{Rails.configuration.config_location}/smtp_config.yml"))
    end
  end
end
