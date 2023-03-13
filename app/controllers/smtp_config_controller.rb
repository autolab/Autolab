require 'psych'

class SmtpConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_config, :administrator
  def update_config
    required_params = %w[protocol host address port enable_starttls_auto authentication username
                         password]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :smtp)) && return
      end
    end

    # create hash from form
    yaml_hash = {
      protocol: params['protocol'],
      host: params['host'],
      address: params['address'],
      port: params['port'],
      enable_starttls_auto: params['enable_starttls_auto'],
      authentication: params['authentication'],
      username: params['username'],
      password: params['password'],
      domain: params['domain']
    }

    # write text parameters to config yml
    File.open("#{Rails.configuration.smtp_config_location}/smtp_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end

    flash[:success] = "SMTP configuration was successfully updated"
    redirect_to autolab_config_admin_path(active: :smtp)
  end
end
