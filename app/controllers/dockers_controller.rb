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
    # flash[:error] = imageFile.read[0..30]
    begin
      TangoClient.build(imageFile.read)
    rescue TangoClient::TangoException => e
      COURSE_LOGGER.log("Error while uploading docker image files")
      raise StandardError.new("Error while uploading docker image: " + e.message)
    end
    redirect_to(action: "index")
  end

end
