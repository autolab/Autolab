class LtiLaunchController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  skip_before_action :authenticate_for_action

  # have to do because we are making a POST request from Canvas
  skip_before_action :verify_authenticity_token

  # action_auth_level :launch, :instructor
  class LtiError < StandardError
    def initialize(msg, status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end
  rescue_from LtiError, with: :respond_with_lti_error
  respond_to :json
  def respond_with_lti_error(error)
    puts(error)
    Rails.logger.send(:warn) {"#{error.status_code} Lti Error: #{error.message}"}
    render :json => {:error => error.message}.to_json, :status => error.status_code
  end

  def validate_oidc_login(params)

    # Validate Issuer.
    if params['iss'].nil?
      raise LtiError.new("Could not find issuer", :bad_request);
    end

    # Validate Login Hint.
    if params['login_hint'].nil?
      raise LtiError.new("Could not find login hint", :bad_request);
    end

    # Fetch Registration Details. Do nothing for now
    # registration = $this->db->find_registration_by_issuer($request['iss']);

    # {Check we got something.
    #   if (empty($registration)) {
    #     throw new OIDC_Exception("Could not find registration details", 1);
    #   }}
  end
  def validate_state(params)
    if (params["state"].nil?)
      raise LtiError.new("no state found", :bad_request)
    end
    # match previous state cookie from oidc_login
    if cookies["lti1p3_#{params["state"]}"] != params["state"]
      raise LtiError.new("state cookie not found or correct", :bad_request)
    end
  end
  def validate_jwt_format(id_token)
    if (id_token.nil?)
      raise LtiError.new("no id token found", :bad_request)
    end
    jwt_parts = id_token.split(".")
    if (jwt_parts.size != 3)
      raise LtiError.new("JWT not valid", :bad_request)
    end
    @jwt = {header: Base64.urlsafe_decode64(jwt_parts[0]),
            body:  Base64.urlsafe_decode64(jwt_parts[1]),
            sig: Base64.urlsafe_decode64(jwt_parts[1])}
  end
  def validate_nonce()
  end
  def launch
    puts(params)
    validate_state(params)
    id_token = params["id_token"]
    validate_jwt_format(id_token)
    validate_nonce()
    # puts(@jwt_parts)
    # @jwt_body = Base64.urlsafe_decode64(@jwt_parts[1])
    render json: @jwt[:body].as_json
    puts("got", params)
  end
  def oidc_login
    # code based on: https://github.com/IMSGlobal/lti-1-3-php-library/blob/master/src/lti/LTI_OIDC_Login.php
    # validate OIDC
    puts("hello", params)
    validate_oidc_login(params)

    # Build OIDC Auth Response
    # Generate State.
    # Set cookie (short lived)
    state = SecureRandom.uuid
    stateCookie = "lti1p3_#{state}"
    cookies[stateCookie] = { value: state, expires_in: 1.hour }

    # generate nonce, store in cache
    nonce = "nonce-#{SecureRandom.uuid}"
    Rails.cache.write('nonce', nonce)
    # build response
    auth_params = {
      "scope": "openid", # oidc scope
      "response_type": "id_token", # oidc response is always an id token
      "response_mode": "form_post", # oidc response is always a form post
      "client_id": Rails.configuration.lti_settings["developer_key"], # client id (developer key)
      "redirect_uri": "http://localhost:3000/lti_launch/launch", # URL to return to after login
      "state": state, # state to identify browser session
      "nonce": nonce, # nonce to prevent replay attacks
      "login_hint": params["login_hint"], # login hint to identify platform session
      "id": "1"
    }
    unless params["lti_message_hint"].nil?
      auth_params["lti_message_hint"] = params["lti_message_hint"]
    end
    # just testing using the Canvas API, above flow not even necessary for this
    # because using manually generated Canvas key
    @auth_params = auth_params
    @test = URI.encode_www_form(auth_params)
    puts("#{Rails.configuration.lti_settings["auth_url"]}?#{@test}")

    puts(auth_params.to_json)
    redirect_to "#{Rails.configuration.lti_settings["auth_url"]}?#{@test}"
    #render html: @response.body.html_safe

    # might use code in future
    # get_service_request(params[:oauth_consumer_key],
    #                     Rails.configuration.lti_settings[params[:oauth_consumer_key]],
    #                     "https://canvas.cmu.edu/api/lti/courses/28853/names_and_roles?access_token=7752~UIBEUM9K5hYc60tuc4OZR8cixYYHXlEWOM9GYo9zKFdAPQlcKQx8FFwBgT5WpzAB")
    # @response = request(:get, "https://canvas.cmu.edu/api/v1/courses/28853/users", {'Authorization' => "Bearer 7752~Bqkw7YLmlSBYGQDV5oBgrMFOevjV8hDNV3gnjBWFJbVsHYrjBSEqdJORKlyk7ma0"})
  end

end
