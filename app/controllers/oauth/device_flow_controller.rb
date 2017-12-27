class Oauth::DeviceFlowController < ActionController::Base

  before_action :set_app

  # For errors encountered during device flow requests
  class DeviceFlowError < StandardError
    attr_reader :status_code # http error code
    
    def initialize(msg = "Unrecognized request", status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end

  rescue_from DeviceFlowError, with: :respond_with_device_flow_error

  # expects params: client_id
  def init
    req = OauthDeviceFlowRequest.create_request(@app)
    if req.nil?
      raise DeviceFlowError.new("Failed to create request, try again later", :internal_server_error)
    end

    # success!
    render :json => {device_code: req.device_code, user_code: req.user_code}.to_json
  end

  # expects params: client_id, device_code
  def authorize
    if not params.has_key?(:device_code)
      raise DeviceFlowError.new("Required param 'device_code' not present", :bad_request)
    end

    req = OauthDeviceFlowRequest.find_by(device_code: params[:device_code])
    if req.nil?
      raise DeviceFlowError.new("Invalid device_code. User may have denied access", :bad_request)
    end

    # check if authorized
    if not req.is_resolved
      raise DeviceFlowError.new("authorization_pending", :bad_request)
    end

    if not req.is_granted
      # user decides to deny access, notify app
      req.destroy
      raise DeviceFlowError.new("authorization denied by user", :bad_request)
    end

    # user granted access, create access token
    token = Doorkeeper::AccessToken.create(:application_id => req.application_id,
                                           :resource_owner_id => req.resource_owner_id,
                                           :scopes => req.scopes)

    # remove request record
    req.destroy

    render :json => {access_token: token.token,
                     token_type: "bearer",
                     expires_in: token.expires_in,
                     refresh_token: token.refresh_token}.to_json
  end

private

  def respond_with_device_flow_error(error)
    render :json => {:error => error.message}.to_json, :status => error.status_code
  end

  def set_app
    if not params.has_key?(:client_id)
      raise DeviceFlowError.new("Required param 'client_id' not present", :bad_request)
    end

    @app = Doorkeeper::Application.find_by(uid: params[:client_id])
    if @app.nil?
      raise DeviceFlowError.new("Unrecongized client_id", :bad_request)
    end
  end

end