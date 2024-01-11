class GithubConfigController < ApplicationController
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  action_auth_level :update_config, :administrator
  def update_config
    required_params = %w[client_id client_secret]
    required_params.each do |param|
      if params[param].blank?
        flash[:error] = "#{param} field was missing"
        redirect_to(autolab_config_admin_path(active: :github)) && return
      end
    end

    Rails.configuration.x.github.client_id = params[:client_id]
    Rails.configuration.x.github.client_secret = params[:client_secret]

    yaml_hash = { github: { client_id: params[:client_id],
                            client_secret: params[:client_secret] } }
    File.open("#{Rails.configuration.config_location}/github_config.yml", "w") do |file|
      file.write(YAML.dump(yaml_hash.deep_stringify_keys))
    end

    flash[:success] = "Github configuration was successfully updated"
    redirect_to autolab_config_admin_path(active: :github)
  end
end
