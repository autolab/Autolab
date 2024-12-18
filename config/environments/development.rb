require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Feature flag for docker image upload
  config.x.docker_image_upload_enabled = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # ID for Heap Analytics
  config.x.analytics_id = nil

  # ID for Google Analytics
  config.x.google_analytics_id = nil

  # OAuth2 Application Configuration for Github
  # See https://docs.autolabproject.com/installation/github_integration/
  if File.size?("#{Rails.configuration.config_location}/github_config.yml")
    config_hash = YAML.safe_load(File.read("#{Rails.configuration.config_location}/github_config.yml"))
    config.x.github.client_id = config_hash['github']['client_id']
    config.x.github.client_secret = config_hash['github']['client_secret']
  end

  if File.size?("#{Rails.configuration.config_location}/smtp_config.yml")
    config_hash = YAML.safe_load(File.read("#{Rails.configuration.config_location}/smtp_config.yml"))

    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.delivery_method = :smtp

    config.action_mailer.default_url_options = {
      protocol: config_hash['protocol'],
      host: config_hash['host']
    }

    config.action_mailer.default_options = {
      from: config_hash['from']
    }

    smtp_settings = {
      address: config_hash['address'],
      port: config_hash['port'],
      enable_starttls_auto: config_hash['enable_starttls_auto'],
      authentication: config_hash['authentication'],
      user_name: config_hash['user_name'],
      password: config_hash['password']
    }

    if config_hash.key?('domain') && !config_hash['domain'].empty?
      smtp_settings[:domain] = config_hash['domain']
    end

    if config_hash.key? 'ssl'
      smtp_settings[:ssl] = config_hash['ssl']
    end

    if config_hash.key? 'tls'
      smtp_settings[:tls] = config_hash['tls']
    end

    config.action_mailer.smtp_settings = smtp_settings
  end

  # Use custom routes for error pages
  config.exceptions_app = self.routes
end
