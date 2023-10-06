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
    flash[:error] = imageFile.open
    begin
      TangoClient.build(imageFile)
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while uploading docker image files")
      raise AutogradeError.new("Error while uploading docker image")
    end
    redirect_to(action: "index")
  end

end
