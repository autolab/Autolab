class LtiNrpsController < ApplicationController
  respond_to :json
  skip_before_action :set_course
  skip_before_action :authorize_user_for_course
  skip_before_action :authenticate_for_action
  skip_before_action :update_persistent_announcements

  rescue_from LtiLaunchController::LtiError, with: :respond_with_lti_error
  def respond_with_lti_error(error)
    Rails.logger.send(:warn) { "Lti NRPS Error: #{error.message}" }
    render json: { error: error.message }.to_json, status: error.status_code
  end
  action_auth_level :request_access_token, :instructor
  def request_access_token
    # get private key from config to sign Autolab's client assertion as a JWK
    private_key = Rails.configuration.lti_settings["tool_private_key"].to_s.gsub(/\\n/, "\n")
    tool_rsa_private = OpenSSL::PKey::RSA.new(private_key)
    # build JWK format for RSA
    optional_parameters = {
      kid: "dGkeZwrt+H7GnGZ2t2LUfhYf+/o=",
      use: 'sig',
      alg: 'RS256',
      e: "AQAB",
      kty: "RSA",
    }
    tool_rsa_private_JWK = JWT::JWK.new(tool_rsa_private, optional_parameters)
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
    # sign client_assertion using private key
    token = JWT.encode(client_assertion, tool_rsa_private_JWK.keypair, optional_parameters[:alg],
                       kid: optional_parameters[:kid])
    # build Client-Credentials Grant
    # https://www.imsglobal.org/spec/security/v1p0/#using-oauth-2-0-client-credentials-grant
    payload = {
      "grant_type": "client_credentials",
      "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      "client_assertion": token,
      "scope": "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"
    }
    # send Client-Credentials Grant to LTI Oauth2 access token endpoint
    conn = Faraday.new(
      url: Rails.configuration.lti_settings["platform_oauth2_access_token_url"],
      headers: { 'Content-Type' => 'application/json' }
    )
    response = conn.post('') do |req|
      req.body = payload.to_json
    end
    response_body = JSON.parse(response.body)
    if response_body["access_token"].nil?
      raise LtiLaunchController::LtiError.new("Client-Credentials Grant Failed: #{response.body}",
                                              :internal_server_error)
    end

    response_body["access_token"]
  end

  # NRPS endpoint for Autolab to send an NRPS request to LTI Advantage Platform
  action_auth_level :sync_roster, :instructor
  def sync_roster
    lcd = LtiCourseDatum.find(params[:lcd_id])
    if lcd.nil? || lcd.membership_url.nil? || lcd.course_id.nil?
      raise LtiLaunchController::LtiError.new("Unable to update roster", :bad_request)
    end

    @lti_context_membership_url = lcd.membership_url
    @course = lcd.course

    # get access token to be authenticated to make NRPS request
    @access_token = request_access_token

    # query NRPS using the access token
    members = query_nrps

    # Update last synced time
    lcd.last_synced = DateTime.current
    lcd.save

    # Update the roster with the retrieved set of members
    @cuds = parse_members_data(lcd, members.as_json)
    @sorted_cuds = @cuds.sort_by { |cud| cud[:color] || "z" }.reverse
  end

private

  def populate_cud_data(cud)
    user = cud.user
    {
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      course_number: cud.course_number,
      lecture: cud.lecture,
      section: cud.section,
      school: user.school,
      major: user.major,
      year: user.year,
      grade_policy: cud.grade_policy
    }
  end

  def parse_members_data(lcd, members_data)
    cuds = @course.course_user_data.all.to_set
    email_to_cud = {}
    cuds.each do |cud|
      email_to_cud[cud.user.email] = cud
    end

    cud_view = []
    members_data.each do |user_data|
      next unless user_data["roles"].include? "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"

      next if user_data.key?("status") && user_data["status"] != "Active"

      next unless user_data.key?("email") && user_data.key?("given_name") &&
                  user_data.key?("family_name")

      # Normalize email
      user_data["email"].downcase!

      cud_data = {}
      user = User.find_by(email: user_data["email"])
      if user.nil? || @course.course_user_data.find_by(user_id: user.id).nil?
        cud_data[:color] = "green"
        cud_data[:email] = user_data["email"]
        cud_data[:first_name] = user_data["given_name"]
        cud_data[:last_name] = user_data["family_name"]
        unless user.nil?
          cud_data[:school] = user.school
          cud_data[:major] = user.major
          cud_data[:year] = user.year
        end
      else
        cud = email_to_cud[user.email]
        cud_data = populate_cud_data(cud)
        cud_data[:color] = "black"
      end

      cud_view << cud_data
      email_to_cud.delete(cud_data[:email])
    end

    return cud_view unless lcd.drop_missing_students

    # Never drop instructors, remove them first
    email_to_cud.delete_if do |_, cud|
      cud.instructor? || cud.user.administrator? || cud.course_assistant?
    end

    # Mark the remaining students as dropped
    email_to_cud.each do |_, cud|
      next if cud.dropped

      cud_data = populate_cud_data(cud)
      cud_data[:color] = "red"
      cud_view << cud_data
    end

    cud_view
  end

  # Query NRPS after being authenticated
  # with logic to handle multi-page queries
  def query_nrps
    # Initially use the context membership url to start querying NRPS
    next_page_url = @lti_context_membership_url
    members = []
    while !next_page_url.nil?
      conn = Faraday.new(
        url: next_page_url,
        headers: { 'Content-Type' => 'application/json' }
      )
      # make a GET request to NRPS endpoint using access token from request_access_token
      response = conn.get("") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
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
      # regex string taken from
      # https://github.com/1EdTech/lti-1-3-php-library/blob/master/src/lti/LTI_Names_Roles_Provisioning_Service.php
      matches = /<([^>]*)>;\s*rel="next"/.match(next_page_header)
      unless matches.nil?
        next_page_url = matches[1]
      end
    end
    members
  end
end
