class Rack::Attack
  class Request < ::Rack::Request
    # get user id from access_token
    # Note: access_token should be present. If not present, request is not throttled.
    def user_id
      return env["attack.user_id"] if env["attack.user_id"]

      token = params['access_token']
      access_token = Doorkeeper::AccessToken.find_by(token: token)
      return token if access_token.nil?

      user = User.find(access_token.resource_owner_id)
      env["attack.user_id"] = user.id
      return user.id
    end
  end

  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blacklisting and
  # whitelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Safelist Requests ###

  # Safelist any request not to API or not to a device_flow auth endpoint
  # Requests to protected api endpoints that do not have an access_token
  # are not throttled because we throttle using access_token. This is ok
  # since these requests will be rejected by doorkeeper immediately anyway.
  safelist('allow from localhost') do |req|
    ((not req.path.start_with?("/api/")) || (not req.params['access_token'])) &&
    (not req.path.start_with?("/oauth/device_flow_")) &&
    (not req.path.include?("getPartialFeedback"))
  end

  ### Throttle Requests ###

  # Throttle all requests by user id
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/general:#{req.user_id}"
  throttle('api/general', :limit => 10, :period => 30.seconds) do |req|
    if req.path.start_with?("/api/")
      req.user_id
    end
  end

  # Throttle requests for assessment submission endpoint
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/submit:#{req.user_id}"
  throttle("api/submit", :limit => 4, :period => 1.minute) do |req|
    if req.path.end_with?("submit")
      req.user_id
    end
  end

  # Throttle requests for device_flow_init
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:oauth/device_flow_init:#{req.user_id}"
  throttle("oauth/device_flow_init", :limit => 1, :period => 30.seconds) do |req|
    if req.path.start_with?("/oauth/device_flow_init")
      req.ip
    end
  end

  # Throttle requests for device_flow_authorize
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:oauth/device_flow_authorize:#{req.user_id}"
  throttle("oauth/device_flow_authorize", :limit => 1, :period => 5.seconds) do |req|
    if req.path.start_with?("/oauth/device_flow_authorize")
      req.ip
    end
  end

  # Throttle requests for getPartialFeedback
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:getPartialFeedback:#{req.ip}"
  throttle("getPartialFeedback", :limit => 1, :period => 5.seconds) do |req|
    req.ip if req.path.include?("getPartialFeedback")
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  self.throttled_responder = lambda do |env|
    now = Time.now
    match_data = env['rack.attack.match_data']

    headers = match_data.nil? ? {} : {
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now.to_i % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    [429, headers, ['{"error": "Too Many Requests. Retry Later."}']]
  end
end