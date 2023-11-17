class DockersController < ApplicationController
  action_auth_level :index, :instructor
  def index
  end

  action_auth_level :uploadDockerImage, :instructor
  def uploadDockerImage
    imageFile = params["imageFile"]
    if imageFile.nil?
      flash[:error] = "Please select a docker image for uploading."
      redirect_to(action: "index")
      return
    end
    begin
      TangoClient.build(imageFile.read)
    rescue TangoClient::TangoException => e
      flash[:error] = "Error while uploading docker image: #{e.message}"
    end
    redirect_to(action: "index")
  end

end
