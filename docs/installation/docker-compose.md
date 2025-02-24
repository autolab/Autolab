# Autolab + Tango Docker Compose Installation

The Autolab Docker Compose installation is a fast and easy production-ready installation and deployment method. It uses a MySQL database for the Autolab deployment, and comes with TLS/SSL support. This is now the preferred way of installing Autolab due to its ease of use.

If you are stuck or find issues with the installation process you can either file an issue on our Github repository, or join our Slack [here](https://communityinviter.com/apps/autolab/autolab-project) and let us know and we will try our best to help. Also see the [debugging](#debugging-your-deployment) section for tips on how to diagnose problems and check out the [troubleshooting](#troubleshooting) section if you run into any issues.

## Installation
First ensure that you have Docker and Docker Compose installed on your machine. See the official <a href="https://docs.docker.com/install/" target="_blank">Docker docs</a> for the installation steps.

1. Clone this repository and its Autolab and Tango submodules: 

        :::bash
        git clone --recurse-submodules -j8 https://github.com/autolab/docker.git autolab-docker


2. Enter the project directory:

        :::bash
        cd autolab-docker

3. Update our Autolab and Tango submodules to ensure that you are getting the latest versions:

        :::bash
        make update

    You may need to install `make` using the appropriate command for your system, such as `apt install make`.

4. Create initial default configs:

        :::bash
        make

5. Build the Dockerfiles for both Autolab and Tango:

        :::bash
        docker compose build

6. Run the Docker containers:

        :::bash
        docker compose up -d

    Note at this point Nginx will still be crash-looping in the Autolab container because TLS/SSL has not been configured/disabled yet.

7. Ensure that the newly created config files have the right permissions, as it may have been modified during the building process:

        :::bash
        make set-perms

8. Perform database migrations for Autolab, which will initialize your database schema:

        :::bash
        make db-migrate

9. Create administrative user for Autolab:

        :::bash
        make create-user

    This user has full permissions on Autolab and will be able to create other users and designate other admins.

10. Change `DOCKER_TANGO_HOST_VOLUME_PATH` in `.env` to be the absolute path to the Tango `volumes` directory, i.e `/<path-to-docker-compose-installation>/Tango/volumes`. This is so that Tango knows where to put the output files of its autograded jobs.

        :::bash 
        # in .env

        # Modify the below to be the path to volumes on your host machine
        DOCKER_TANGO_HOST_VOLUME_PATH=/home/your-user/autolab-docker/Tango/volumes

11. Stop all containers, as we are going to setup/disable TLS:

        :::bash 
        docker compose stop

12. Update the Nginx config. Update all occurrences of `REPLACE_WITH_YOUR_DOMAIN` in `nginx/app.conf` and `nginx/no-ssl-app.conf` to your real domain name. The configs are used when TLS is enabled and disabled respectively. Double-check that ALL occurrences are replaced as otherwise you will have trouble accessing your deployment.

13. Continue with TLS setup as outlined in the [next section](#configuring-tlsssl)

14. Build the autograding image(s) that you want to use in Tango (see [the docs](/installation/tango/#docker-vmms-setup) for more information). For this setup we will stick to the default Ubuntu 18.04 autograding image: 

        :::bash
        docker build -t autograding_image Tango/vmms/
        
    Note that we can just run this directly on the host because we are mapping the Docker socket to the Tango container (i.e they are using the same Docker server).

15. Start up everything: 

        :::bash
        docker compose up -d
        
    Autolab should now be accessible on port 80 (and 443 if you configured TLS)! You can now go on to configure mailing, [follow the instructions for setting up mailing](/installation/mailing/) with the only difference being that the paths mentioned are relative to the directory `Autolab/`.

16. Now you are all set to start using Autolab! Please fill out [this form](https://docs.google.com/forms/d/e/1FAIpQLSctfi3kwa03yuCuLgGF7qS_PItfk__1s80twhVDiKGQHvqUJg/viewform?usp=sf_link) to join our registry so that we can provide you with news about the latest features, bug-fixes, and security updates. For more info, visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab). 
## Configuring TLS/SSL
Having TLS/SSL configured is important as it helps to ensure that sensitive information like user credentials and submission information are encrypted instead of being sent over in plaintext across the network when users are using Autolab. We have made setting up TLS as easy and pain-free as possible. Using TLS is strongly recommended if you are using Autolab in a production environment with real students and instructors.

There are three options for TLS: using Let's Encrypt (for free TLS certificates), using your own certificate, and not using TLS (suitable for local testing/development, but not recommended for production deployment).

### Option 1: Let's Encrypt
1. Ensure that your DNS record points towards the IP address of your server
2. Ensure that port 443 is exposed on your server (i.e checking your firewall, AWS security group settings, etc)
3. In `ssl/init-letsencrypt.sh`, change `domains=(example.com)` to the list of domains that your host is associated with, and change `email` to be your email address so that Let's Encrypt will be able to email you when your certificate is about to expire
4. If necessary, change `staging=0` to `staging=1` to avoid being rate-limited by Let's Encrypt since there is a limit of 20 certificates/week. Setting this is helpful if you have an experimental setup.
5. Run your modified script: `sudo ./ssl/init-letsencrypt.sh`

### Option 2: Using your own TLS certificate
1. Copy your private key to `ssl/privkey.pem`
2. Copy your certificate to `ssl/fullchain.pem`
3. Generate your dhparams:

        :::bash
        openssl dhparam -out ssl/ssl-dhparams.pem 4096

4. Uncomment the following lines in `docker-compose.yml`:

        :::bash
        # - ./ssl/fullchain.pem:/etc/letsencrypt/live/test.autolab.io/fullchain.pem;
        # - ./ssl/privkey.pem:/etc/letsencrypt/live/test.autolab.io/privkey.pem;
        # - ./ssl/ssl-dhparams.pem:/etc/letsencrypt/ssl-dhparams.pem

### Option 3: No TLS (not recommended, only for local development/testing)
1. In `docker-compose.yml`, comment out the following:

        :::bash
        # Comment the below out to disable SSL (not recommended)
        - ./nginx/app.conf:/etc/nginx/sites-enabled/webapp.conf
    
2. In `docker-compose.yml`, also uncomment the following:

        :::bash
        # Uncomment the below to disable SSL (not recommended)
        # - ./nginx/no-ssl-app.conf:/etc/nginx/sites-enabled/webapp.conf
    
3. Lastly, in `.env` file, set `DOCKER_SSL=false`:

        :::bash
        # set to false for no SSL (not recommended)
        DOCKER_SSL=false

## Updating Your Docker Compose Deployment
1. Stop your running instances:

        :::bash
        docker compose stop

2. Update your Autolab and Tango repositories:

        :::bash
        make update

3. Rebuild the images with the latest code:

        :::bash
        docker compose build

4. Re-deploy your containers:

        :::bash
        docker compose up

## Debugging your Deployment
In the (very likely) event that you run into problems during setup, hopefully these steps will help you to help identify and diagnose the issue. If you continue to face difficulties or believe you discovered issues with the setup process please join our Slack [here](https://communityinviter.com/apps/autolab/autolab-project) and let us know and we will try our best to help.

### Better logging output for Docker Compose
By default, `docker compose up -d` runs in detached state and it is not easy to immediately see errors:

    :::bash
    $ docker compose up -d
    Starting certbot ... done
    Starting redis   ... done
    Starting mysql   ... done
    Starting tango     ... done
    Recreating autolab ... done

Use `docker compose up` instead to get output from all the containers in real time:

    :::bash
    $ docker compose up
    Starting certbot ... done
    Starting mysql   ... done
    Starting redis   ... done
    Starting tango   ... done
    Starting autolab ... done
    Attaching to redis, mysql, certbot, tango, autolab
    mysql      | [Entrypoint] MySQL Docker Image 8.0.22-1.1.18
    tango      | 2020-11-11 04:33:19,533 CRIT Supervisor running as root (no user in config file)
    redis      | 1:C 11 Nov 2020 04:33:19.032 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
    redis      | 1:C 11 Nov 2020 04:33:19.032 # Redis version=6.0.9, bits=64, commit=00000000, modified=0, pid=1, just started
    redis      | 1:C 11 Nov 2020 04:33:19.032 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
    mysql      | [Entrypoint] Starting MySQL 8.0.22-1.1.18
    redis      | 1:M 11 Nov 2020 04:33:19.033 * Running mode=standalone, port=6379.
    redis      | 1:M 11 Nov 2020 04:33:19.033 # Server initialized
    tango      | 2020-11-11 04:33:19,539 INFO RPC interface 'supervisor' initialized
    tango      | 2020-11-11 04:33:19,539 CRIT Server 'unix_http_server' running without any HTTP authentication checking
    mysql      | 2020-11-11T04:33:19.476749Z 0 [System] [MY-010116] [Server] /usr/sbin/mysqld (mysqld 8.0.22) starting as process 22
    --- output truncated ---

### Checking Autolab logs
If the Autolab instance is not working properly, taking a look at both the application logs as well as the Nginx logs in the container will be helpful.

First, find the name of the container. This should be just `autolab` by default:

    :::bash
    $ docker ps
    CONTAINER ID        IMAGE                       COMMAND                  CREATED             STATUS                    PORTS                                      NAMES
    765d35962f52        autolab-docker_autolab      "/sbin/my_init"          31 minutes ago      Up 22 minutes             0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   autolab
    a5b77b5267b1        autolab-docker_tango        "/usr/bin/supervisor…"   7 days ago          Up 22 minutes             0.0.0.0:3000->3000/tcp                     tango
    438d8e9f73e2        redis:latest                "docker-entrypoint.s…"   7 days ago          Up 22 minutes             6379/tcp                                   redis
    da86acc5a4c3        mysql/mysql-server:latest   "/entrypoint.sh mysq…"   7 days ago          Up 22 minutes (healthy)   3306/tcp, 33060-33061/tcp                  mysql
    88032e85d669        a2eb12050715                "/bin/bash"              9 days ago          Up 2 days                                                            compiler

Next get a shell inside the container:

    :::bash
    $ docker exec -it autolab bash
    root@be56be775428:/home/app/webapp# 

By default we are in the project directory. Navigate to the `logs` directory and `cat` or `tail` `production.log`. This contains logs from the Autolab application itself.

    :::bash
    root@be56be775428:/home/app/webapp# cd log
    root@be56be775428:/home/app/webapp/log# tail -f -n +1 production.log 

We can also check out our Nginx logs in `/var/log/nginx/`:

    :::bash
    root@be56be775428:/home/app/webapp/log# cd /var/log/nginx/
    root@be56be775428:/var/log/nginx# ls
    access.log  error.log

### Accessing the Rails console
Obtain a shell in the `autolab` container as described [previously](#checking-autolab-logs), and do `RAILS_ENV=production bundle exec rails c`:

    :::bash
    root@be56be775428:/home/app/webapp# RAILS_ENV=production bundle exec rails c
    Loading production environment (Rails 5.2.0)
    2.6.6 :001 > User.all.count
    => 1

In the example above, if you performed `make create-user` you should have at least one user in your database. If there are errors connecting to a database here it is likely that the database was misconfigured.

### Checking Tango Logs
Get a shell in the Tango instance, similar to the instructions mentioned [previously](#checking-autolab-logs). The logs are stored in the parent folder (`/opt/TangoService`) of the project directory:

    :::bash
    $ docker exec -it tango bash
    root@a5b77b5267b1:/opt/TangoService/Tango# cd ..
    root@a5b77b5267b1:/opt/TangoService# ls
    Tango  tango_job_manager_log.log  tango_log.log
    root@a5b77b5267b1:/opt/TangoService# tail -f -n +1 tango_job_manager_log.log tango_log.log 

### Troubleshooting Autolab/Tango Connection
In the Autolab container, try to curl Tango:

    :::bash
    root@be56be775428:/home/app/webapp# curl tango:3000
    Hello, world! RESTful Tango here!

In the Tango container, try to curl Autolab:

    :::bash
    root@a5b77b5267b1:/opt/TangoService/Tango# curl autolab
    <html>
    <head><title>301 Moved Permanently</title></head>
    <body bgcolor="white">
    <center><h1>301 Moved Permanently</h1></center>
    <hr><center>nginx/1.14.0 (Ubuntu)</center>
    </body>
    </html>

### Permission issues in Autolab
Run the following again:

    :::bash
    make set-perms

### Restarting Autolab Passenger Server
This is useful when you might want to test out some code change within the Autolab container without having to rebuild everything again. These changes can be applied by just restarting the Passenger service that is serving Autolab.

Run `passenger-config restart-app`:

    :::bash
    root@8b56488b3fb6:/home/app/webapp# passenger-config restart-app
    Please select the application to restart.
    Tip: re-run this command with --help to learn how to automate it.
    If the menu doesn't display correctly, press '!'

    ‣   /home/app/webapp (production)
    Cancel

    Restarting /home/app/webapp (production)

## Troubleshooting
### error: unable to unlink old 'db/schema.rb': Permission denied

If you obtain the following error when attempting to perform `make update`:

    :::bash
    error: unable to unlink old 'db/schema.rb': Permission denied
    fatal: Could not reset index file to revision 'HEAD'.

This is due to the fact that `db/schema.rb` is updated whenever migrations are performed. `db/schema.rb` documents the database schema, which depends on the database that you are using, its version, and when the migrations were run. It is likely that your `db/schema.rb` will diverge from the one generated by the devs.

You can resolve this by changing the owner of the files to be your current user, and then running `make set-perms` afterwards when you start the containers again.

### Autograder logs not appearing

This happens when you are accessing Autolab via localhost, as Tango will attempt to send the autograder logs to its own localhost instead.

To remedy this, add `127.0.0.1 autolab` to `/etc/hosts` and access Autolab via `http://autolab` instead of `http://localhost`.

If you are accessing Autolab on a different host, add `<your public_ip> <your fqdn> autolab` to your `/etc/hosts` file and access Autolab via `http://autolab`.    
