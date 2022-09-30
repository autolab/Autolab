class LtiIntegrationController < ApplicationController
  respond_to :json
  before_action :doorkeeper_authorize! # OAuth2 token authentication for all actions

  action_auth_level :launch, :student
  def launch
    if not Rails.configuration.lti_settings[params[:oauth_consumer_key]]
      puts("HELLO")
      render json: { error: "we did not receive the oauth" }, status: 401
      return
    end
    puts("got consumer key")
    render json: { body: "hello" }, status: :ok
    require 'oauth/request_proxy/action_controller_request'
    @provider = IMS::LTI::ToolProvider.new(
      params[:oauth_consumer_key],
      Rails.configuration.lti_settings[params[:oauth_consumer_key]],
      params
    )

    if not @provider.valid_request?(request)
      # the request wasn't validated
      render :launch_error, status: 401
      return
    end
    puts("we got a valid request")
    puts(params)
  end
  def index
    puts("pain")
    render json: { error: "in pain" }, status: 200
  end
end
