class Api::V1::BaseApiController < ActionController::Base

  before_action :doorkeeper_authorize! # OAuth2 token authentication for all actions

  respond_to :json

  private

  def current_user
    @current_user ||= User.find(doorkeeper_token[:resource_owner_id])
  end

end