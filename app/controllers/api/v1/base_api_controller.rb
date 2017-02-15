class Api::V1::BaseApiController < ActionController::Base

  # Error type for APIs
  class ApiError < StandardError
    attr_reader :status_code # http error code
    
    def initialize(msg = "Unrecognized request", status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end

  rescue_from ApiError, with: :respond_with_api_error

  before_action :doorkeeper_authorize! # OAuth2 token authentication for all actions

  respond_to :json

  private

  def current_user
    @current_user ||= User.find(doorkeeper_token[:resource_owner_id])
  end

  def respond_with_api_error(error)
    render :json => {:error => error.message}.to_json, :status => error.status_code
  end

end