# Mailing Setup

Autolab requires mailing to allow users to register accounts and reset passwords. You will also be able to make announcements through Autolab as well. The recommended approach is to setup Autolab to use a SMTP server, such as [mailgun](https://mailgun.com), [SendGrid](https://sendgrid.com), [Amazon SES](https://aws.amazon.com/ses/) or any other valid SMTP mail servers to send out email.

We intend this instructions mainly for production usage. To set Autolab up to use a custom SMTP Server, edit the following in `production.rb` that you have created. (If you would like to test it in development, add the following settings into `development.rb`). Both `production.rb` and `development.rb` are located at `config/environments`

1. Update the host domain of your Autolab frontend instance

        :::ruby
        config.action_mailer.default_url_options = {protocol: 'http', host: 'yourhost.com' }
    
    Host here should be the domain in which Autolab is hosted on. (e.g. `autolab.andrew.cmu.edu`)

2. Update the custom smtp server settings
   
        :::ruby
        config.action_mailer.smtp_settings = {
                address:              'smtp.example.com',
                port:                 25,
                enable_starttls_auto: true,
                authentication:       'login',
                user_name:            'example',
                password:             'example',
                domain:               'example.com',
        }
        
      Refer to the SMTP settings instructions that your selected service provides you such as [SendGrid SMTP for Ruby on Rails](https://sendgrid.com/docs/for-developers/sending-email/rubyonrails/), [Amazon SES](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-smtp.html).

3. Update the "from" setting
   
        :::ruby
        ActionMailer::Base.default :from => 'something@example.com'
  
      Here the from address **must** be a address that your SMTP service permits you to send from. Oftentimes it is the same as your user_name in the smtp settings.

Make sure to restart your Autolab client to see the changes 