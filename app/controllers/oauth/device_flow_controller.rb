class Oauth::DeviceFlowController < ActionController::Base
  # expects params: client_id
  def init
    if not params.has_key?(:client_id)
      render json: {:error => "Required param 'client_id' not present"}, status: :bad_request
      return
    end

    app = Doorkeeper::Application.find_by(uid: params[:client_id])
    if app.nil?
      render json: {:error => "Unrecongized client_id"}, status: :bad_request
      return
    end

    req = OauthDeviceFlowRequest.create_request(app)
    if req.nil?
      render json: {:error => "Failed to create request, try again later"}, status: :internal_server_error
      return
    end

    # success!
    render json: {device_code: req.device_code, user_code: req.user_code}, status: :ok
  end

  def authorize
    puts "AUTHORIZE"
    render json: {:msg => "got authorize"}
  end
end