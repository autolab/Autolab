require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(:default, Rails.env)

module Autolab3
  class Application < Rails::Application
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
      Devise::SessionsController.layout "home"
      Devise::RegistrationsController.layout proc{ |controller| user_signed_in? ? "application"   : "home" }
      Devise::ConfirmationsController.layout "home"
      Devise::UnlocksController.layout "home"            
      Devise::PasswordsController.layout "home"        
    end

    # TODO: this should be a macro
    config.action_mailer.default_url_options = {protocol: 'https', host: 'autograder.cse.buffalo.edu' }

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

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

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Customize form control error state: controls with erroneous input get wrapped with this
    config.action_view.field_error_proc = Proc.new { |html_tag, instance| 
      "<div class=\"field_with_errors has-error\">#{html_tag}</div>".html_safe
    }

    # Allow embedding as iFrame on external sites
    config.action_dispatch.default_headers.merge!({'X-Frame-Options' => 'ALLOWALL'})

    # Allow MOSS to work with as many files as it wants
    Rack::Utils.multipart_part_limit = 0
  end
end
