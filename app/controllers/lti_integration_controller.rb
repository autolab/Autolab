class LtiIntegrationController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  skip_before_action :authenticate_for_action

  # have to do because we are making a POST request from Canvas
  skip_before_action :verify_authenticity_token
  action_auth_level :launch, :instructor
  def launch
    # check that consumer key from canvas is correct
    if not Rails.configuration.lti_settings[params[:oauth_consumer_key]]
      render json: { error: "we did not receive the oauth" }, status: :unauthorized
      return
    end

    # required for oauth to work
    require 'oauth/request_proxy/action_controller_request'
    # create "Tool Provider" using IMS LTI gem
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

    # just testing using the Canvas API, above flow not even necessary for this
    # because using manually generated Canvas key
    conn = Faraday.new(
      "https://canvas.cmu.edu/api/v1/",
      headers: {'Authorization' => "Bearer 7752~Bqkw7YLmlSBYGQDV5oBgrMFOevjV8hDNV3gnjBWFJbVsHYrjBSEqdJORKlyk7ma0"}
    ) do |f|
      f.response :json
    end
    @response = conn.get("courses/28853/users").body;

    puts(@response.to_s)
    render :inline => "<pre><%= JSON.pretty_generate(@response) %></pre>"

    # might use code in future
    # get_service_request(params[:oauth_consumer_key],
    #                     Rails.configuration.lti_settings[params[:oauth_consumer_key]],
    #                     "https://canvas.cmu.edu/api/lti/courses/28853/names_and_roles?access_token=7752~UIBEUM9K5hYc60tuc4OZR8cixYYHXlEWOM9GYo9zKFdAPQlcKQx8FFwBgT5WpzAB")
    #@response = request(:get, "https://canvas.cmu.edu/api/v1/courses/28853/users", {'Authorization' => "Bearer 7752~Bqkw7YLmlSBYGQDV5oBgrMFOevjV8hDNV3gnjBWFJbVsHYrjBSEqdJORKlyk7ma0"})
  end

end
