class LtiIntegrationController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  skip_before_action :authenticate_for_action

  # have to do because we are making a POST request from Canvas
  skip_before_action :verify_authenticity_token
  action_auth_level :launch, :student
  def launch
    if not Rails.configuration.lti_settings[params[:oauth_consumer_key]]
      puts("HELLO")
      render json: { error: "we did not receive the oauth" }, status: :unauthorized
      return
    end
    puts("got consumer key")
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
    puts("AUTH COMPLETE")
    puts(@provider.username)
    @return_url = @provider.build_return_url
    render json: { body: params }, status: :ok
    #redirect_to(@return_url)
  end
end
