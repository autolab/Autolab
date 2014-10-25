# Load the rails application
require File.expand_path('../application', __FILE__)

# TODO: get Exception Notifier working again!
# ExceptionNotification::Notifier.exception_recipients = %w(autolab-dev@andrew.cmu.edu)
# ExceptionNotification::Notifier.sender_address =  "Indiana Jones <indy@autolab.cs.cmu.edu>"

# Initialize the rails application
Autolab3::Application.initialize!
