require 'action_mailer'
require 'tempfile'
require 'psych'

class SmtpConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_config, :administrator
  def update_config
    required_params = %w[protocol host address port authentication communication_protocol
                         default_from]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :smtp)) && return
      end
    end

    smtp_settings, default_url_options, default_options = params_to_settings params

    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.default_url_options = default_url_options
    ActionMailer::Base.smtp_settings = smtp_settings
    ActionMailer::Base.default_options = default_options

    yaml_hash = smtp_settings.merge default_url_options
    yaml_hash.merge! default_options
    File.open("#{Rails.configuration.config_location}/smtp_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end

    flash[:success] = "SMTP configuration was successfully updated"
    redirect_to autolab_config_admin_path(active: :smtp)
  end

  def send_test_email
    required_params = %w[protocol host address port authentication communication_protocol to_email
                         from_email default_from]

    # Create temp file to save the new configuration
    smtp_settings, default_url_options, default_options = params_to_settings params

    required_params.each do |param|
      next if params[param].present?

      flash[:error] = "#{param} field was missing"
      redirect_to(autolab_config_admin_path(active: :smtp)) && return
    end

    # Save old settings to be restored
    old_deliver_method = ActionMailer::Base.delivery_method
    old_default_url_options = ActionMailer::Base.default_url_options

    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.default_url_options = default_url_options

    begin
      @email = CourseMailer.test_email(params[:from_email], params[:to_email], smtp_settings)
      @email.deliver
    rescue StandardError => e
      flash[:error] = "Error sending test email: #{e.message}"
    else
      flash[:success] = "Test email sent successfully"
    ensure
      ActionMailer::Base.delivery_method = old_deliver_method
      ActionMailer::Base.default_url_options = old_default_url_options

      yaml_hash = smtp_settings.merge default_url_options
      yaml_hash.merge! default_options

      Rails.cache.write(:tmp_smtp_config, yaml_hash)
      redirect_to autolab_config_admin_path(active: :smtp)
    end
  end

private

  def params_to_settings(params)
    smtp_settings = {
      address: params['address'],
      port: params['port'],
      enable_starttls_auto: params['enable_starttls_auto'] == 'true',
      authentication: params['authentication'],
      user_name: params['username'],
      password: params['password']
    }

    if params.key?(:domain) && !params[:domain].empty?
      smtp_settings[:domain] = params['domain']
    end

    case params['communication_protocol']
    when 'ssl'
      smtp_settings[:ssl] = true
    when 'tls'
      smtp_settings[:tls] = true
    end

    default_url_options = {
      protocol: params['protocol'],
      host: params['host']
    }

    default_options = {
      from: params['default_from']
    }

    [smtp_settings, default_url_options, default_options]
  end
end
