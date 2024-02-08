require "tango_client"

class DockersController < ApplicationController
  action_auth_level :index, :instructor
  def index; end

  action_auth_level :uploadDockerImage, :instructor
  def uploadDockerImage
    image_name = params[:image_name]
    image_file = params[:image_file]
    if image_name.nil? || image_name.empty?
      flash[:error] = "Please specify an image name."
    elsif %r{\A[a-z0-9](_{0,2}[a-z0-9])*(/[a-z0-9](_{0,2}[a-z0-9])*)?\z}.match(image_name).nil?
      flash[:error] =
        "Please specify a valid image name comprised of lowercase letters, digits, and \
         underscores. You may use one forward slash separator."
    elsif image_file.nil?
      flash[:error] = "Please select a docker image for uploading."
    else
      begin
        TangoClient.build(image_name, image_file.read)
        flash[:success] = "Successfully uploaded docker image"
      rescue TangoClient::TangoException => e
        flash[:error] = "Error while uploading docker image: #{e.message}"
      rescue StandardError => e
        flash[:error] = "Unexpected error occurred: #{e.message}"
      end
    end
    redirect_to(action: "index")
  end
end
