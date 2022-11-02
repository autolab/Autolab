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
    Rails.logger.send(:warn) {"Lti Error: #{error.message}"}
    render :json => {:error => error.message}.to_json, :status => 400
  end

  def validate_oidc_login(params)

    # Validate Issuer. Different than other LTI implementations since for now
    # we will only support integration with one service
    if params['iss'].nil? && params['iss'] != Rails.configuration.lti_settings["iss"]
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
      raise LtiError.new("no id token found in request", :bad_request)
    end
    jwt_parts = id_token.split(".")
    if (jwt_parts.size != 3)
      raise LtiError.new("JWT not valid", :bad_request)
    end
    @jwt = {header: JSON.parse(Base64.urlsafe_decode64(jwt_parts[0])),
            body:  JSON.parse(Base64.urlsafe_decode64(jwt_parts[1])),
            sig: JSON.parse(Base64.urlsafe_decode64(jwt_parts[1]))}
  end
  def validate_nonce()
    if (@jwt[:body]["nonce"].nil?)
      raise LtiError.new("no nonce found in request", :bad_request)
    end
    cache_nonce = Rails.cache.read('nonce')
    if (cache_nonce.nil?)
      raise LtiError.new("nonce in cache expired", :bad_request)
    end
    if (cache_nonce != @jwt[:body]["nonce"])
      raise LtiError.new("nonce doesn't match cache", :bad_request)
    end

  end
  # validate issuer
  def validate_registration()
    client_id = @jwt[:body]['aud'].is_a?(Array) ? @jwt[:body]['aud'][0] : @jwt[:body]['aud'];
    if (client_id != Rails.configuration.lti_settings["developer_key"])
      # Client not registered.
      raise LtiError.new("client id not registered for issuer", :bad_request)
    end
    if (@jwt[:body]['iss'] != Rails.configuration.lti_settings["iss"])
      raise LtiError.new("iss doesn't match config", :bad_request)
    end
  end

  # Right now, we only allow / validate LtiResourceLinkRequest
  # since this is the message type needed for launches to get
  # course context information needed for syncing
  def validate_link_request()
    message_type = @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/message_type"]
    if (message_type.nil? || message_type != "LtiResourceLinkRequest")
      raise LtiError.new("LTI launch is not an LtiResourceLinkRequest", :bad_request)
    end
    id = @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/resource_link"]["id"]
    if id.nil?
      raise LtiError.new("Missing Resource Link ID", :bad_request)
    end
    # checking for required fields of id token
    # http://www.imsglobal.org/spec/security/v1p0/#id-token
    if (@jwt[:body]['sub'].nil?)
      raise LtiError.new("sub required in LTI launch", :bad_request)
    end
    # check that claim version is for LTI Advantage
    if (@jwt[:body]['https://purl.imsglobal.org/spec/lti/claim/version'] != "1.3.0")
      raise LtiError.new("launch claim version is not 1.3.0", :bad_request)
    end
    if (@jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/roles"].nil?)
      raise LtiError.new("Roles claim not found", :bad_request)
    end

  end
  def validate_jwt_signature(id_token)
    rsa_public = OpenSSL::PKey::RSA.new(Rails.configuration.lti_settings["platform_public_key"])
    begin
    decoded_token = JWT.decode id_token, rsa_public, true, { algorithm: 'RS256' }
    rescue JWT::ExpiredSignature
      # Handle expired token, e.g. logout user or deny access
      raise LtiError.new("JWT signature expired", :bad_request)
      end
    rescue JWT::ImmatureSignature
      # Handle invalid token, e.g. logout user or deny access
      raise LtiError.new("JWT signature invalid", :bad_request)
    end
  def launch
    puts(params)
    validate_state(params)
    id_token = params["id_token"]
    validate_jwt_format(id_token)
    validate_jwt_signature(id_token)
    validate_nonce()
    validate_registration()
    validate_link_request()
    if (!current_user.present?)
      raise LtiError.new("Not logged in!", :bad_request)
    end
    @user = current_user
    redirect_to :controller => "users", :action => "lti_launch_initialize", :launch_context => @jwt[:body], :id=> @user.id
    # puts(@jwt_parts)
    # @jwt_body = Base64.urlsafe_decode64(@jwt_parts[1])
    #render json: @jwt[:body].as_json
    #puts("got", params)

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
