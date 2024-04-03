class LtiLaunchController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements
  skip_before_action :authenticate_for_action

  # have to do because we are making a POST request from Canvas
  skip_before_action :verify_authenticity_token

  action_auth_level :launch, :instructor
  class LtiError < StandardError
    attr_reader :status_code

    def initialize(msg, status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end
  rescue_from LtiError, with: :respond_with_lti_error

  def respond_with_lti_error(error)
    Rails.logger.send(:warn) { "Lti Launch Error: #{error.message}" }
    render json: { error: error.message }.to_json, status: error.status_code
  end

  # validate we get iss login_hint params for oidc entrypoint
  def validate_oidc_login(params)
    # Validate Issuer. Different than other LTI implementations since for now
    # we will only support integration with one service, if more than one
    # integration enabled, then changed to check a list of issuers
    if params['iss'].nil? && params['iss'] != @lti_config_hash["iss"]
      raise LtiError.new("Could not find issuer", :bad_request)
    end

    # Validate Login Hint.
    return unless params['login_hint'].nil?

    raise LtiError.new("Could not find login hint", :bad_request)
  end

  # check state matches what was already sent in oidc_login
  def validate_state(params)
    if params["state"].nil?
      raise LtiError.new("no state found", :bad_request)
    end
    # match previous state cookie from oidc_login
    return unless cookies["lti1p3_#{params['state']}"] != params["state"]

    raise LtiError.new("state cookie not found or correct", :bad_request)
  end

  # ensure id_token is a valid jwt
  def validate_jwt_format(id_token)
    if id_token.nil?
      raise LtiError.new("no id token found in request", :bad_request)
    end

    jwt_parts = id_token.split(".")
    if jwt_parts.size != 3
      raise LtiError.new("JWT not valid", :bad_request)
    end

    @jwt = { header: JSON.parse(Base64.urlsafe_decode64(jwt_parts[0])),
             body: JSON.parse(Base64.urlsafe_decode64(jwt_parts[1])),
             sig: JSON.parse(Base64.urlsafe_decode64(jwt_parts[1])) }
  end

  # validate nonce is same as initially sent during oidc_login
  def validate_nonce
    if @jwt[:body]["nonce"].nil?
      raise LtiError.new("no nonce found in request", :bad_request)
    end

    cache_nonce = Rails.cache.read("nonce-#{@user.id}")
    if cache_nonce.nil?
      raise LtiError.new("nonce in cache expired", :bad_request)
    end
    return unless cache_nonce != @jwt[:body]["nonce"]

    raise LtiError.new("nonce doesn't match cache", :bad_request)
  end

  # validate issuer, client_id should be same as stored in our settings
  def validate_registration
    client_id = @jwt[:body]['aud'].is_a?(Array) ? @jwt[:body]['aud'][0] : @jwt[:body]['aud']
    if client_id != @lti_config_hash["developer_key"]
      # Client not registered.
      raise LtiError.new("client id not registered for issuer", :bad_request)
    end
    return unless @jwt[:body]['iss'] != @lti_config_hash["iss"]

    raise LtiError.new("iss doesn't match config", :bad_request)
  end

  # Right now, we only allow / validate LtiResourceLinkRequest
  # since this is the message type needed for launches to get
  # course context information needed for syncing
  def validate_link_request
    message_type = @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/message_type"]
    if message_type.nil? || message_type != "LtiResourceLinkRequest"
      raise LtiError.new("LTI launch is not an LtiResourceLinkRequest", :bad_request)
    end

    id = @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/resource_link"]["id"]
    if id.nil?
      raise LtiError.new("Missing Resource Link ID", :bad_request)
    end
    # checking for required fields of id token
    # http://www.imsglobal.org/spec/security/v1p0/#id-token
    if @jwt[:body]['sub'].nil?
      raise LtiError.new("sub required in LTI launch", :bad_request)
    end
    # check that claim version is for LTI Advantage
    if @jwt[:body]['https://purl.imsglobal.org/spec/lti/claim/version'] != "1.3.0"
      raise LtiError.new("launch claim version is not 1.3.0", :bad_request)
    end
    return unless @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/roles"].nil?

    raise LtiError.new("Roles claim not found", :bad_request)
  end

  # make sure that we are given the context_memberships_url
  # otherwise, we can't call / access NRPS
  def validate_nrps_access
    # rubocop:disable Layout/LineLength
    if @jwt[:body]['https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice'].nil? ||
       @jwt[:body]['https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice']['context_memberships_url'].nil? ||
       @jwt[:body]['https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice']['context_memberships_url'].empty?
      raise LtiError.new("NRPS context membership url not found", :bad_request)
    end
    # rubocop:enable Layout/LineLength
  end

  def get_public_key(platform_public_key_file, platform_public_jwks)
    # import public key depending on whether we have a JSON file
    # with a single JWK or list of JWKs
    if !platform_public_key_file.nil?
      begin
        platform_public_key_json = JSON.parse(platform_public_key_file)
        # import could fail b/c this assumes only one key is specified, not list of keys
        rsa_public_key = JWT::JWK.import(platform_public_key_json).public_key
        return rsa_public_key
      rescue StandardError => e
        Rails.logger.error(e)
        return nil
      end
    end
    platform_public_jwks.each do |platform_public_key|
      # JWT has a "key-id" header which specifies which public key to use
      next unless platform_public_key["kid"] == @jwt[:header]["kid"]

      begin
        rsa_public_key = JWT::JWK::RSA.import(platform_public_key).public_key
        return rsa_public_key
      rescue StandardError
        return nil
      end
    end
    nil
  end

  def validate_jwt_signature(id_token)
    # use JWK URL over file
    if !@lti_config_hash["platform_public_jwks_url"].nil? &&
       @lti_config_hash["platform_public_jwks_url"].present?
      # fetch JWKS from provided keys URL
      conn = Faraday.new(
        url: @lti_config_hash["platform_public_jwks_url"],
        headers: { 'Content-Type' => 'application/json' }
      )
      # make a GET request to public JWK endpoint
      response = conn.get("")
      if response.body["keys"].nil?
        raise LtiError.new("No keys were found from public JWK url", :internal_server_error)
      end

      platform_public_jwks = JSON.parse(response.body)["keys"]
    elsif File.size?("#{Rails.configuration.config_location}/lti_platform_jwk.json")
      # static platform public key, so take key from yml
      platform_public_key_file =
        File.read("#{Rails.configuration.config_location}/lti_platform_jwk.json")
    else
      raise LtiError.new("No platform public key or public JWK url provided",
                         :internal_server_error)
    end
    rsa_public_key = get_public_key(platform_public_key_file, platform_public_jwks)
    if rsa_public_key.nil?
      raise LtiError.new("No matching JWK found", :bad_request)
    end

    begin
      JWT.decode id_token, rsa_public_key, true, { algorithm: 'RS256' }
    rescue JWT::ExpiredSignature
      # Handle expired token, e.g. logout user or deny access
      raise LtiError.new("JWT signature expired", :bad_request)
    rescue JWT::ImmatureSignature
      # Handle invalid token, e.g. logout user or deny access
      raise LtiError.new("JWT signature invalid", :bad_request)
    end
  end

  # final LTI launch flow endpoint
  # validate id_token, jwt, check we have NRPS access
  # redirect to users/:id/lti_launch_initialize for final linking
  def launch
    # Code based on:
    # https://github.com/IMSGlobal/lti-1-3-php-library/blob/master/src/lti/LTI_Message_Launch.php
    unless File.size?("#{Rails.configuration.config_location}/lti_config.yml")
      raise LtiError.new("LTI configuration not found on Autolab Server", :internal_server_error)
    end

    # load LTI configuration from file
    @lti_config_hash =
      YAML.safe_load(File.read("#{Rails.configuration.config_location}/lti_config.yml"))

    @user = current_user
    validate_state(params)
    id_token = params["id_token"]
    validate_jwt_format(id_token)
    validate_jwt_signature(id_token)
    validate_nonce
    validate_registration
    validate_link_request
    validate_nrps_access
    if !current_user.present?
      raise LtiError.new("Not logged in!", :bad_request)
    end

    redirect_to lti_launch_initialize_user_path(
      @user,
      course_memberships_url: @jwt[:body]["https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice"]["context_memberships_url"],
      course_title: @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
      platform: @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/tool_platform"]["name"],
      context_id: @jwt[:body]["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
    )
  end

  # LTI launch entrypoint to initiate open id connect login
  # build our authentication response and redirect back to
  # platform
  def oidc_login
    unless File.size?("#{Rails.configuration.config_location}/lti_config.yml")
      raise LtiError.new("LTI configuration not found on Autolab Server", :internal_server_error)
    end

    # load LTI configuration from file
    @lti_config_hash =
      YAML.safe_load(File.read("#{Rails.configuration.config_location}/lti_config.yml"))

    # code based on: https://github.com/IMSGlobal/lti-1-3-php-library/blob/master/src/lti/LTI_OIDC_Login.php
    # validate OIDC
    validate_oidc_login(params)
    # Build OIDC Auth Response
    # Generate State.
    # Set cookie (short lived)
    state = SecureRandom.uuid
    stateCookie = "lti1p3_#{state}"
    cookies[stateCookie] = { value: state, expires_in: 1.hour }

    # generate nonce, store in cache for user
    @user = current_user
    nonce = "nonce-#{SecureRandom.uuid}"
    Rails.cache.write("nonce-#{@user.id}", nonce, expires_in: 3600)
    prefix = "https://"
    if ENV["DOCKER_SSL"] == "false"
      prefix = "http://"
    end
    begin
      hostname = if Rails.env.development?
                   request.base_url
                 else
                   prefix + request.host
                 end
    rescue StandardError
      hostname = `hostname`
      hostname = prefix + hostname.strip
    end

    # build response
    auth_params = {
      "scope": "openid", # oidc scope
      "response_type": "id_token", # oidc response is always an id token
      "response_mode": "form_post", # oidc response is always a form post
      "client_id": @lti_config_hash["developer_key"], # client id (developer key)
      "redirect_uri": "#{hostname}/lti_launch/launch", # URL to return to after login
      "state": state, # state to identify browser session
      "nonce": nonce, # nonce to prevent replay attacks
      "login_hint": params["login_hint"], # login hint to identify platform session
      "prompt": "none"
    }
    unless params["lti_message_hint"].nil?
      auth_params["lti_message_hint"] = params["lti_message_hint"]
    end

    # put auth params as URL query parameters for redirect
    @encoded_params = URI.encode_www_form(auth_params)

    redirect_to "#{@lti_config_hash['auth_url']}?#{@encoded_params}"
  end
end
