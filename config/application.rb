require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Autolab3
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # config.load_defaults 5.0
    # NOTE: uncommenting the above sets active_record.belongs_to_required_by_default = true
    # This breaks some existing code (e.g. create course, create assessment)

    config.to_prepare do
      Devise::ConfirmationsController.skip_before_action :set_course
      Devise::ConfirmationsController.skip_before_action :authorize_user_for_course
      Devise::ConfirmationsController.skip_before_action :authenticate_for_action
      Devise::ConfirmationsController.skip_before_action :update_persistent_announcements
      Devise::SessionsController.skip_before_action :set_course
      Devise::SessionsController.skip_before_action :authorize_user_for_course
      Devise::SessionsController.skip_before_action :authenticate_for_action
      Devise::SessionsController.skip_before_action :update_persistent_announcements
      Devise::PasswordsController.skip_before_action :set_course
      Devise::PasswordsController.skip_before_action :authorize_user_for_course
      Devise::PasswordsController.skip_before_action :authenticate_for_action
      Devise::PasswordsController.skip_before_action :update_persistent_announcements
      Devise::RegistrationsController.skip_before_action :set_course
      Devise::RegistrationsController.skip_before_action :authorize_user_for_course
      Devise::RegistrationsController.skip_before_action :authenticate_for_action
      Devise::RegistrationsController.skip_before_action :update_persistent_announcements
      Devise::OmniauthCallbacksController.skip_before_action :set_course
      Devise::OmniauthCallbacksController.skip_before_action :authorize_user_for_course
      Devise::OmniauthCallbacksController.skip_before_action :authenticate_for_action
      Devise::OmniauthCallbacksController.skip_before_action :update_persistent_announcements
      Devise::SessionsController.layout "application"
      Devise::RegistrationsController.layout "application"
      Devise::ConfirmationsController.layout "application"
      Devise::UnlocksController.layout "application"
      Devise::PasswordsController.layout "application"
      Doorkeeper::AuthorizationsController.layout "application"
      Doorkeeper::AuthorizedApplicationsController.layout "application"
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake time:zones:all" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = "Eastern Time (US & Canada)"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Don't fall back to assets pipeline if a precompiled asset is missed
    config.assets.compile = true


    # Generate digests for assets URLs
    config.assets.digest = false
    config.serve_static_files = false

    # Added in Rails 5
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Customize form control error state: controls with erroneous input get wrapped with this
    config.action_view.field_error_proc = Proc.new { |html_tag, instance|
      html_tag.html_safe
    }

    # Allow embedding as iFrame on external sites
    config.action_dispatch.default_headers.merge!({'X-Frame-Options' => 'ALLOWALL'})

    # Allow MOSS to work with as many files as it wants
    Rack::Utils.multipart_part_limit = 0

    # School specific configuration (please edit config/school.yml)
    config.school = config_for(:school)

    # configure throttling middleware rack-attack
    config.middleware.use Rack::Attack

    # site version
    config.site_version = "2.12.0"

    # Set application host for mailer
    config.action_mailer.default_url_options = { host: ENV['MAILER_HOST'] || "YOUR_APP_HOST" }

    # Configure the host and port of generated urls
    config.action_controller.default_url_options = {}

    ENV['DEFAULT_URL_HOST'] = "" if ENV['DEFAULT_URL_HOST'].nil?
    ENV['DEFAULT_URL_PORT'] = "" if ENV['DEFAULT_URL_PORT'].nil?
    if !ENV['DEFAULT_URL_HOST'].empty?
      config.action_controller.default_url_options[:host] = ENV['DEFAULT_URL_HOST']
      if ENV['DEFAULT_URL_PORT'].casecmp?("NONE") then
        config.action_controller.default_url_options[:port] = nil
      elsif !ENV['DEFAULT_URL_PORT'].empty?
        config.action_controller.default_url_options[:port] = ENV['DEFAULT_URL_PORT']
      end
    end

    # Configuration file path, keep it private
    config.config_location = Rails.root.join("config").to_s

    # Ensures correct error message if no secret_key_base is defined
    if !ENV['SECRET_KEY_BASE'].nil? && ENV['SECRET_KEY_BASE'].empty?
      ENV.delete('SECRET_KEY_BASE')
    end

  end
end
