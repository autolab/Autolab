source 'https://rubygems.org'
ruby '3.2.2'

gem 'rails', '=6.1.7.6'

# Use SCSS for stylesheets
gem 'sass-rails', '>= 4.0.3'

# Use Materialize for the base css
gem 'materialize-sass', "=1.0.0"

# Use for some of the glypicons on the site
gem 'bootstrap-sass', '>= 3.4.1'

# Use for Metrics page
gem 'fomantic-ui-sass', '2.8.8.1'

# Use Uglifier as compressor for JavaScript assets
gem 'terser', '>= 1.1.7'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '>= 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'mini_racer', '~> 0.6.3', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '>= 2.0'

# bundle exec rails doc:rails generates the API under doc/api.
gem 'sdoc', '>= 0.4.0', group: :doc

# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
gem 'spring', group: :development

# Sourcing environment variables from .env
gem 'dotenv-rails'

# Enables Slack notifications
gem 'slack-notifier'
# E-mail autolab-dev on exceptions in production
gem 'exception_notification', ">= 4.1.0"

# Used by lib/tasks/autolab.rake to populate DB with dummy seed data
gem 'rake', '>=10.3.2'
gem 'populator', '>=1.0.0'

# To communicate with MySQL database
gem 'mysql2', '~>0.5'

# Development server
gem 'thin'

# External authentication
gem 'devise', '>=4.5.0'
gem 'omniauth', '>=1.2.2'
gem 'omniauth-facebook', '>=2.0.0'
gem 'omniauth-google-oauth2', '>=0.2.5'
gem 'omniauth-rails_csrf_protection', '~> 1.0'
gem 'omniauth-shibboleth', '>=1.1.2'
gem 'omniauth-shibboleth-redux', '~> 2.0', require: 'omniauth-shibboleth'

# OAuth2 authentication
gem 'oauth2'

# Github API
gem "octokit", "~> 4.0"

# Autolab API OAuth Service
gem 'doorkeeper'

# For block and throttling abusive requests
gem 'rack-attack'

# Adds It also adds f.error_messages and f.error_message_on to form builders
gem 'dynamic_form'

# Supports zip file generation.
gem 'rubyzip'

# Helper gem for Ruby JSON API client
gem 'httparty'

# Enables RSpec testing framework with Capybara and FactoryBot.
gem 'capybara', group: [:development, :test]
gem 'rack-test'
gem 'rspec-rails', '>=3.5.0'
# To enable webdriver testing capabilities along with capybara
gem 'selenium-webdriver', '>=4.16', group: :test
gem "webrick", "~> 1.8"
# required for capybara debugging
gem 'codeclimate-test-reporter', group: :test, require: nil
gem 'database_cleaner', group: [:development, :test]
gem 'factory_bot_rails', group: [:development, :test]
gem 'launchy', group: :test
gem 'newrelic_rpm'
gem 'webmock', group: [:development, :test]

# Automatic Time Zone Management
gem 'browser-timezone-rails'
gem 'js_cookie_rails'

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Dates and times
gem 'bootstrap3-datetimepicker-rails', '>= 4.17.47'
gem 'momentjs-rails', '>= 2.9.0'
gem 'moment_timezone-rails'

# Force SSL on certain routes
gem 'rack-ssl-enforcer'

group :development do
  # Better Error Pages
  gem 'better_errors'
  gem 'binding_of_caller' # enhances better_errors

  # static code analyzer
  gem 'erb_lint', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false

  # pre-commit hook for rubocop
  gem 'overcommit'

  # documentation generator
  gem 'yard'

  # sqlite3 adapter
  gem 'sqlite3', '1.5.1'
end

# Also install sqlite3 for docker installations
if ENV['DEPLOY_METHOD'] == "docker"
  gem 'sqlite3', '1.5.1'
end

gem 'tzinfo-data'

# Useful debugger
gem 'byebug', '>=3.5.1'

# for PDF annotations
# This is an outdate version however support for
# templating has been dropped in the future versions
# and it is crucial for us
gem 'prawn', '0.13.0'

# for submission diffs
gem 'diffy'

# LDAP Lookup
gem 'net-ldap'

gem 'sprockets-rails', '>=3.2.1'

gem "jstz-rails3-plus", ">= 1.0"

# For getting file types
gem 'mimemagic', '>= 0.3.7'

# For encrypting API tokens
gem 'lockbox'

# to decode / verify jwts for LTI Integration
gem "jwt"

# Avoid "already initialized constant" errors (https://github.com/ruby/net-imap/issues/16)
gem "net-http"
gem 'uri', '0.10.3'
