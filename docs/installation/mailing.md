# Mailing Setup

Autolab requires mailing to allow users to register accounts and reset passwords. You will also be able to make announcements through Autolab as well. The recommended approach is to setup Autolab to use a SMTP server, such as [mailgun](https://mailgun.com), [SendGrid](https://sendgrid.com), [Amazon SES](https://aws.amazon.com/ses/) or any other valid SMTP mail servers to send out email.

We intend these instructions mainly for production usage.

## Mailing for Autolab version >=3.0.0
To set up Autolab (>=3.0.0) for a custom SMTP Server, configure settings by clicking `Manage Autolab` > `Configure Autolab` > `SMTP Config`.

## I don't have a domain name, will mailing work?
Mailing has been tested to work with SendGrid without a domain name (using the IP of the server as the domain name for the purposes of the configuration above), although the absence of a domain name will likely result in the email to be flagged as spam. For the purpose of testing, a testing mailbox service like [MailTrap](https://mailtrap.io/) is recommended.

## What if I'm running an outdated version of Autolab?
If you are running an Autolab version less than v3.0.0, refer to the documentation down below to configure SMTP.

### Mailing for Autolab Docker Installation
To set Autolab Docker up for a custom SMTP Server, update the following in `.env` that was created for you.

1. Update the host domain

        :::
        HOST_PROTOCOL=http
        HOST_DOMAIN=example.com

2. Update custom smtp settings

        :::
        SMTP_SETTINGS_ADDRESS=smtp.example.com
        SMTP_SETTINGS_PORT=25
        SMTP_SETTINGS_ENABLE_STARTTLS_AUTO=true
        SMTP_SETTINGS_AUTHENTICATION=login
        SMTP_SETTINGS_USER_NAME=example
        SMTP_SETTINGS_PASSWORD=example
        SMTP_SETTINGS_DOMAIN=example.com

       Refer to the SMTP settings instructions that your selected service provides you such as [SendGrid SMTP for Ruby on Rails](https://sendgrid.com/docs/for-developers/sending-email/rubyonrails/), [Amazon SES](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-smtp.html).

3. Update from setting

        :::
        SMTP_DEFAULT_FROM=from@example.com

       Here the from address **must** be an address that your SMTP service permits you to send from. Oftentimes it is the same as your user_name in the smtp settings.

After which, doing a `docker-compose down` followed by `docker-compose up -d` will allow you to see the changes.

### Mailing for Autolab Manual Installation
To set Autolab up to use a custom SMTP Server, you will need to make edits to the `.env` and `production.rb` files that you have created. (If you would like to test it in development, add the following settings into `development.rb`). Both `production.rb` and `development.rb` are located under `config/environments`

1. Update the host domain of your Autolab instance in `.env`

        :::
        MAILER_HOST=yourhost.com

       The value should be the domain in which Autolab is hosted on. (e.g. `autolab.andrew.cmu.edu`)

2. Update the custom smtp server settings in `production.rb`

        :::ruby
        config.action_mailer.smtp_settings = {
                address:              'smtp.example.com',
                port:                 25,
                enable_starttls_auto: true,
                authentication:       'plain', # Other options include: 'login', 'cram_md5'
                user_name:            'example',
                password:             'example',
                domain:               'example.com',
        }

   Refer to the SMTP settings instructions that your selected service provides you such as [SendGrid SMTP for Ruby on Rails](https://sendgrid.com/docs/for-developers/sending-email/rubyonrails/), [Amazon SES](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-smtp.html).

3. Update the "from" setting in `production.rb`

        :::ruby
        ActionMailer::Base.default :from => 'something@example.com'

   Here the from address **must** be an address that your SMTP service permits you to send from. Oftentimes it is the same as your user_name in the smtp settings.

Make sure to restart your Autolab client to see the changes.
