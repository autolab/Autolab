# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require "spec_helper"
require "contexts_helper"
require File.expand_path('../config/environment', __dir__)
require "rspec/rails"
require 'capybara/rspec'
require 'capybara/rails'
require "devise"
require "selenium/webdriver"

include Contexts

# Requires supporting ruby files in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.include ActionDispatch::TestProcess
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = Rails.root.join("spec/fixtures")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Helper configuration for rspec.
  config.infer_spec_type_from_file_location!
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.extend ControllerMacros, type: :controller

  MiniRacer::Platform.set_flags! :single_threaded

  config.include Capybara::DSL
  # rack_test to be used when selenium is not necessary as it is faster
  Capybara.default_driver = :rack_test
  Capybara.server = :webrick

  # driver needed for Selenium to run
  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(app, browser: :chrome)
  end

  Capybara.register_driver :headless_chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new(
      args: %w[headless no-sandbox disable-gpu disable-dev-shm-usage],
    )

    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options:
    )
  end
  # change to chrome to see execution on browser
  Capybara.javascript_driver = :headless_chrome

  # Before hooks for initialization
  config.before(:suite) do
    Capybara.app_host = "http://localhost:8200"
    Capybara.run_server = true
    Capybara.server_port = 8200
  end

  # After hooks for cleanup
  config.after(:suite) do
    Scheduler.delete_all
  end
end
