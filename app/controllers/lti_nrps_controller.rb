class LtiNrpsController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :update_persistent_announcements

  class LtiError < StandardError
    def initialize(msg, status_code = :bad_request)
      @status_code = status_code
      super(msg)
    end
  end
  rescue_from LtiError, with: :respond_with_lti_error

  def respond_with_lti_error(error)
    Rails.logger.debug(error)
    Rails.logger.send(:warn) { "Lti Error: #{error.message}" }
    render json: { error: error.message }.to_json, status: :bad_request
  end

  def request_access_token
    # get private key from config to sign Autolab's client assertion
    private_key = Rails.configuration.lti_settings["tool_private_key"].to_s.gsub(/\\n/,"\n")
    tool_rsa_private = OpenSSL::PKey::RSA.new(private_key)
    optional_parameters = {
      kid: "dGkeZwrt+H7GnGZ2t2LUfhYf+/o=",
      use: 'sig',
      alg: 'RS256',
      e: "AQAB",
      kty: "RSA",
    }
    tool_rsa_private_JWK = JWT::JWK.new(tool_rsa_private, optional_parameters);
    # build client assertion based on lti 1.3 spec
    # https://www.imsglobal.org/spec/security/v1p0/#using-json-web-tokens-with-oauth-2-0-client-credentials-grant
    # https://www.imsglobal.org/spec/lti/v1p3#token-endpoint-claim-and-services
    client_assertion = {
      "iss": Rails.configuration.lti_settings["developer_key"],
      "sub": Rails.configuration.lti_settings["developer_key"],
      "aud": Rails.configuration.lti_settings["platform_oauth2_access_token_url"],
      "iat": Time.now.to_i,
      "exp": Time.now.to_i + 600,
      "jti": "lti-refresh-token-#{SecureRandom.uuid}"
    }
    puts(tool_rsa_private_JWK.to_s)
    # sign client_assertion using private key
    token = JWT.encode(client_assertion, tool_rsa_private_JWK.keypair, optional_parameters[:alg], kid: optional_parameters[:kid])
    puts(token)
    # build Client-Credentials Grant
    # https://www.imsglobal.org/spec/security/v1p0/#using-oauth-2-0-client-credentials-grant
    payload = { "grant_type": "client_credentials",
                "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                "client_assertion": token,
                "scope":
                  "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly" }
    conn = Faraday.new(
      url: Rails.configuration.lti_settings["platform_oauth2_access_token_url"],
      headers: { 'Content-Type' => 'application/json' }
    )
    # send Client-Credentials Grant to LTI Oauth2 access token endpoint
    response = conn.post('') do |req|
      req.body = payload.to_json
    end
    response_body = JSON.parse(response.body)
    if response_body["access_token"].nil?
      raise LtiError.new("Client-Credentials Grant Failed: #{response.body}", :bad_request)
    end

    response_body["access_token"]
  end

  def query_nrps
    next_page_url = @lti_context_membership_url
    members = []
    while !next_page_url.nil?
      conn = Faraday.new(
        url: next_page_url,
        headers: { 'Content-Type' => 'application/json' }
      )
      response = conn.get("") do |req|
        req.headers["Authorization"] = @access_token
        req.headers["Accept"] = "application/vnd.ims.lti-nrps.v2.membershipcontainer+json"
        # filter on Learners
        req.params["role"] = "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
      end
      # append member page to array
      members.concat(JSON.parse(response.body)["members"])

      # determine if there are more pages
      # More information on member pagination:
      # https://www.imsglobal.org/spec/lti-nrps/v2p0#limit-query-parameter
      next_page_url = nil
      next_page_header = response.headers["link"]
      next if next_page_header.nil?

      # regex match for next page link
      # regex string taken from https://github.com/1EdTech/lti-1-3-php-library/blob/master/src/lti/LTI_Names_Roles_Provisioning_Service.php
      matches = /^Link:.*<([^>]*)>; ?rel="next"/i.match(next_page_header)
      unless matches.nil?
        next_page_url = matches[1]
      end
    end
    members
  end

  def send_nrps_request
    @lti_context_membership_url = params[:lti_context_membership_url]
    @course = params[:course]

    # get access token to be authenticated to make NRPS request
    @access_token = request_access_token

    # query NRPS using the access token
    members = query_nrps
    render json: members.as_json
  end
end
