class Rack::Attack

  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blacklisting and
  # whitelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new 

  ### Safelist any request not to API ###
  Rack::Attack.safelist('allow from localhost') do |req|
    not req.path.start_with?("/api/")
  end

  ### Throttle General API Requests ###

  # Throttle all requests by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/general:#{req.ip}"
  throttle('api/general', :limit => 10, :period => 30.seconds) do |req|
    req.ip
  end

  # Throttle requests for assessment submission endpoint
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/submit:#{req.ip}"
  throttle("api/submit", :limit => 4, :period => 1.minute) do |req|
    if req.path.end_with?("submit")
      req.ip
    end
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  # self.throttled_response = lambda do |env|
  #  [ 503,  # status
  #    {},   # headers
  #    ['']] # body
  # end
end