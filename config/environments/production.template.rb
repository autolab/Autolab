Autolab3::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = false

  config.assets.enabled = true
  # Compress JavaScripts and CSS
  config.assets.js_compressor = Uglifier.new(harmony: true)
  config.assets.css_compressor = :sass

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true
  config.middleware.use Rack::SslEnforcer, :except => [ /log_submit/, /local_submit/ ]


  # See everything in the log (default is :info)
  config.log_level = :info

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Provide context to the email generator about the host
  #config.action_mailer.default_url_options = {protocol: 'http', host: 'example.com' }

  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Use a custom smtp server, like Mandrill
  #config.action_mailer.smtp_settings = {
  #  address:              'smtp.mandrillapp.com',
  #  port:                 25,
  #  enable_starttls_auto: true,
  #  authentication:       'login',
  #  user_name:            'MANDRILL_USERNAME',
  #  password:             'MANDRILL_PASSWORD',
  #  domain:               'example.com',
  #}

  config.middleware.use ExceptionNotification::Rack,
    email: {
      email_prefix: "[Autolab Error] ",
      sender_address: "\"NOTIFIER\" <NOTIFICATIONS@YOURAPP.com>",
      exception_recipients: "TEAM@YOURAPP.COM"
    }


  # ID for Heap Analytics
  config.x.analytics_id = nil

end
