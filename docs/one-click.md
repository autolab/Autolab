# Autolab + Tango OneClick Installation

OneClick is the fastest way to install Autolab and Tango on an Ubuntu VM. The installation uses packages Autolab, MySQL, and Tango into seperate Docker containers with specific exposed ports for communication.

There are two types of installations. A local development setup and a real-world ready setup that requires SSL certificates, email service configuration, and domain name registration. Use the local setup for experimentation before deploying in a real-world scenario on such apps like Heroku, EC2, or DigitalOcean, among others.

## Local OneClick Setup

### 1. Prepare an Ubuntu VM

These installation instructions are for Ubuntu. If you're on other operating system, we recommend you set up an Ubuntu virtual machine first with [Virtual Box](https://www.virtualbox.org/wiki/Downloads).

About the System Configuration:

-   [Ubuntu 14.04( or higher) 64bit](http://www.ubuntu.com/download/alternative-downloads)
-   2GB memory + 20GB disk

To set up, [Install Ubuntu on Virtualbox](http://www.wikihow.com/Install-Ubuntu-on-VirtualBox) may help you.

**Optional:**

For better experience, we also recommend you to "insert guest additional CD image" for your virtual machine to enable full screen.
(If you installed Ubuntu 16+, you can skip this)

```
Devices > Insert guest additional CD image
```

Also enable clipboard share for easier copy and paste between host and VM.

```
Settings > Advanced > Shared Clipboard > Bidrectional
```

You need to restart your virtual machine to validate these optional changes.

### 2. Download

Root is required to install Autolab:

```bash
sudo -i
```

Clone repo:

```bash
git clone https://github.com/autolab/autolab-oneclick.git; cd autolab-oneclick
```

### 3. Installation

Run the following in the autolab-oneclick folder

```bash
./install.sh -l
```

This will take a few minutes. Once you see `Autolab Installation Finished`, ensure all docker containers are running:

```bash
docker ps
# CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                    PORTS                     NAMES
# c8679844bbfa        local_web           "/sbin/my_init"          3 months ago        Exited (0) 3 months ago                             local_web_1         721 kB (virtual 821 MB)
# 45a9e30241ea        mysql               "docker-entrypoint..."   3 months ago        Exited (0) 3 months ago   0.0.0.0:32768->3306/tcp   local_db_1          0 B (virtual 383 MB)
# 1ef089e2dca4        local_tango         "sh start.sh"            3 months ago        Exited (0) 3 months ago   0.0.0.0:8600->8600/tcp    local_tango_1       91.1 kB (virtual 743 MB)
```

Now Autolab is successfully installed and running on your virtual machine.
Open your browser and visit `localhost:3000`, you will see the landing page of Autolab.

Follow the instructions [here](#testing) to test out your set up.

## Server/Production OneClick Setup

### 1. Provision a Server

**Server**

If you don't already have a server, we recommend a VPS (virtual private server). Here are a couple popular VPS providers:

-   [DigitalOcean](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-14-04) (recommended)
-   [Amazon Lightsail](https://amazonlightsail.com)
-   [Google Cloud Platform](https://cloud.google.com/)

**Domain name**

(A domain name is both required by SSL and email service.)

In your DNS provider:

-   Add www and @ records pointing to the ip address of your server.
-   Add DKIM and SFF records by creating TXT records after you finish the email service part.

**SSL**

You can run Autolab with or without HTTPS encryption. We strongly recommend you run it with HTTPS.

Here are a few options to get the SSL certificate and key:

1.  Go through your school/organization

    Many universities have a program whereby they'll grant SSL certificates to students and faculty for free. Some of these programs require you to be using a school-related domain name, but some don't. You should be able to find out more information from your school's IT department.

2.  Use paid service: SSLmate

    You can follow this [simple guide](https://sslmate.com/help/getting_started) to get your paid SSL with [SSLMate](https://sslmate.com/) in the simplest way.

#### Email Service

Autolab uses email for various features, include sending out user confirmation emails and instructor-to-student bulk emails. You can use MailChimp + Mandrill to configure transactional email.

1. Create a MailChimp account [here](https://login.mailchimp.com/signup)

2. Add Mandrill using [these instructions](http://kb.mailchimp.com/mandrill/mailchimp-vs-mandrill)

3. Go to the settings page and create a new API key

4. From the Mailchimp/Mandrill Domains settings page, add your domain

5. Configure the DKIM and SFF settings by creating TXT records with your DNS provider (they link to some instructions for how to do this, but the process will differ depending on which DNS provider you are using. Try Google!).

### 2. Download and Configuration

1.  Use root to install Autolab

        :::bash
        sudo -i

2.  Clone the installation package

        :::bash
        git clone https://github.com/autolab/autolab-oneclick.git; cd autolab-oneclick

3.  Generate a new secret key for Devise Auth Configuration:

        :::bash
        python -c "import random; print hex(random.getrandbits(512))[2:-1]"

    Update the values in `server/configs/devise.rb`

        :::ruby
        config.secret_key = <GENERATED_SECRET_KEY>
        config.mailer_sender = <EMAIL_ADDRESS_WITH_YOUR_HOSTNAME>

4.  **With SSL:**

    Copy your SSL certificate and key file into the `server/ssl` directory.

    **Without SSL**:

    Comment out the following lines in `server/configs/nginx.conf`

        :::ruby
        # EFF recommended SSL settings
        # ssl_prefer_server_ciphers on;
        # ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:ECDH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5:!DSS;
        # ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";


    Comment out the following line in `server/configs/production.rb`

        :::ruby
        # config.middleware.use Rack::SslEnforcer, :except => [ /log_submit/, /local_submit/ ]

6.  Configure Nginx in `server/configs/nginx.conf`

        :::ruby
        server_name <YOUR_SERVER_DOMAIN>
        ssl_certificate /path/to/ssl_certificate/file
        ssl_certificate_key /path/to/ssl_certificate_key/file

7.  Configure Email in `server/configs/production.rb`. Update the address, port, user_name, password and domain with your email service informations. For Mandrill, go to "SMTP & API Info" to see the informations.

### 3. Installation

1.  Start Installation

        ::bash
        cd autolab-oneclick
        ./install.sh -s

    Answer the prompts and wait until you see `Autolab Installation Finished`.

2.  Ensure docker containers are running

        :::bash
        docker ps
        # CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                    PORTS                     NAMES
        # c8679844bbfa        local_web           "/sbin/my_init"          3 months ago        Exited (0) 3 months ago                             local_web_1         721 kB (virtual 821 MB)
        # 45a9e30241ea        mysql               "docker-entrypoint..."   3 months ago        Exited (0) 3 months ago   0.0.0.0:32768->3306/tcp   local_db_1          0 B (virtual 383 MB)
        # 1ef089e2dca4        local_tango         "sh start.sh"            3 months ago        Exited (0) 3 months ago   0.0.0.0:8600->8600/tcp    local_tango_1       91.1 kB (virtual 743 MB)

Now Autolab is successfully installed and running on your virtual machine.
Open your browser and visit `https://yourdomainname`, to see the landing page of Autolab.

Follow the instructions [here](#testing) to test out your set up.

## Testing

Login with the following credentials:

```bash
email: admin@foo.bar
password: adminfoobar
```

We have populated dummy data for you to test with.

Run the following commands to cleanup the dummy data:

```bash
cd local
docker-compose run --rm -e RAILS_ENV=production web rake autolab:depopulate
```
