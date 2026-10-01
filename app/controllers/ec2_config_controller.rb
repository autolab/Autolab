class Ec2ConfigController < ApplicationController
  # This is a global setting, so it doesn't belong to a specific course
  skip_before_action :set_course

  # Only global administrators can access this action
  action_auth_level :update, :administrator

  def update
    # Get the checked boxes from the form. If none are checked, default to empty array.
    allowed_instances = params[:allowed_instances] || []

    # Package it into a Ruby Hash
    config_hash = { "allowed_instances" => allowed_instances }

    # Put changes in a YAML config file
    config_path = "#{Rails.configuration.config_location}/ec2_config.yml"

    # Write the Hash to the file as YAML
    File.open(config_path, "w") do |file|
      file.write(config_hash.to_yaml)
    end

    # 5. Show a success message
    flash[:success] = "EC2 Instance Limits updated successfully."

    # Redirect back to the EC2 tab
    redirect_to controller: "admins", action: "autolab_config", active: "ec2"
  end
end
