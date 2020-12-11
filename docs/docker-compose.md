# Autolab + Tango Docker Compose Installation

The Autolab Docker Compose installation is a fast and easy production-ready installation and deployment method. It uses a MySQL database for the Autolab deployment, and comes with SSL support. This is now the preferred way of installing Autolab.

If you are stuck or find issues with the installation process you can either file an issue on our Github repository, or join our Slack [here](https://autolab-slack.herokuapp.com/) and let us know and we will try our best to help. Also see the [debugging](#debugging) section for tips on how to diagnose problems.

## Installation
First ensure that you have Docker and Docker Compose installed on your machine. See the official [Docker docs](See https://docs.docker.com/install/) for the installation steps.

1. Clone this repository and its submodules: `git clone --recurse-submodules -j8 git://github.com/autolab/docker.git autolab-docker`
2. Enter the project directory: `cd autolab-docker`
3. Update submodules: `make update`
4. Create initial configs: `make`
5. Build the Dockerfiles: `docker-compose build`
6. Run the containers: `docker-compose up -d`. Note at this point Nginx will still be crash-looping in the Autolab container because SSL has not been configuired/disabled yet.
7. Ensure that the newly created config files have the right permissions: `make set-perms`
8. Perform migrations: `make db-migrate`
9. Create initial root user: `make create-user`
10. Stop all containers: `docker-compose stop`
11. Continue with TLS setup as outlined in the next section
12. Build the autograding image(s) that you want to use in Tango (see [the docs](https://docs.autolabproject.com/tango-vmms/#docker-vmms-setup) for more information). For this setup we will stick to the default Ubuntu 14.04 autograding image: `docker build -t autograding_image Tango/vmms/`. Note that we can just run this directly on the host because we are mapping the Docker socket to the Tango container (i.e they are using the same Docker server).
13. Start up everything: `docker-compose up -d`. Autolab should now be accessible on port 80 (and 443 if you configured SSL)!

## Configuring SSL/TLS
There are three options for TLS: using Let's Encrypt (for free TLS certificates), using your own certificate, and not using TLS (not recommended for production deployment).

### Option 1: Let's Encrypt
1. Ensure that your DNS record points towards the IP address of your server
2. Ensure that port 443 is exposed on your server (i.e checking your firewall, AWS security group settings, etc)
3.  Get initial SSL setup script: `make ssl`
4. In `ssl/init-letsencrypt.sh`, change `domains=(example.com)` to the list of domains that your host is associated with, and change `email` to be your email address so that Let's Encrypt will be able to email you when your certificate is about to expire
5. If necessary, change `staging=0` to `staging=1` to avoid being rate-limited by Let's Encrypt since there is a limit of 20 certificates/week. Setting this is helpful if you have an experimental setup.
6. Run your modified script: `sudo sh ./ssl/init-letsencrypt.sh`

### Option 2: Using your own TLS certificate
1. Copy your private key to ./ssl/privkey.pem
2. Copy your certificate to ./ssl/fullchain.pem
3. Generate your dhparams, i.e `openssl dhparam -out ./ssl/ssl-dhparams.pem 4096`
4. Uncomment the following lines in `docker-compose.yml`:
```
    # - ./ssl/fullchain.pem:/etc/letsencrypt/live/test.autolab.io/fullchain.pem;
    # - ./ssl/privkey.pem:/etc/letsencrypt/live/test.autolab.io/privkey.pem;
    # - ./ssl/ssl-dhparams.pem:/etc/letsencrypt/ssl-dhparams.pem
```

### Option 3: No TLS (not recommended, only for local development/testing)
1. In `docker-compose.yml` (for all the subsequent steps), comment out the following:

``` 
    # Comment the below out to disable SSL (not recommended)
    - ./nginx/app.conf:/etc/nginx/sites-enabled/webapp.conf
```
    
Also uncomment the following:

```
   # Uncomment the below to disable SSL (not recommended)
   # - ./nginx/no-ssl-app.conf:/etc/nginx/sites-enabled/webapp.conf
```
    
Lastly set `DOCKER_SSL=false`:
```
    environment:
      - DOCKER_SSL=true                         # set to false for no SSL (not recommended)
```

## Updating Autolab/Tango Deployment
1. Stop your running instances: `docker-compose stop`
2. Run `make update` to update your Autolab and Tango repositories
3. Run `docker-compose build` to rebuild the images with the latest code
4. Re-deploy your containers with `docker-compose up`

## Debugging your Deployment
In the (very likely) event that you run into problems during setup, hopefully these steps will help you to help identify and diagnose the issue. If you continue to face difficulties or believe you discovered issues with the setup process please join our Slack [here](https://autolab-slack.herokuapp.com/) and let us know and we will try our best to help.

### Better logging output for Docker Compose
By default, `docker-compose up -d` runs in detached state and it is not easy to immediately see errors:

```
$ docker-compose up -d
Starting certbot ... done
Starting redis   ... done
Starting mysql   ... done
Starting tango     ... done
Recreating autolab ... done
```

Use `docker-compose up` instead to get output from all the containers in real time:

```
$ docker-compose up
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
```

### Checking Autolab logs
If the Autolab instance is not working properly, taking a look at both the application logs as well as the Nginx logs in the container will be helpful.

First, find the name of the container. This should be just `autolab` by default:

```
$ docker ps
CONTAINER ID        IMAGE                       COMMAND                  CREATED             STATUS                    PORTS                                      NAMES
765d35962f52        autolab-docker_autolab      "/sbin/my_init"          31 minutes ago      Up 22 minutes             0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   autolab
a5b77b5267b1        autolab-docker_tango        "/usr/bin/supervisor…"   7 days ago          Up 22 minutes             0.0.0.0:3000->3000/tcp                     tango
438d8e9f73e2        redis:latest                "docker-entrypoint.s…"   7 days ago          Up 22 minutes             6379/tcp                                   redis
da86acc5a4c3        mysql/mysql-server:latest   "/entrypoint.sh mysq…"   7 days ago          Up 22 minutes (healthy)   3306/tcp, 33060-33061/tcp                  mysql
88032e85d669        a2eb12050715                "/bin/bash"              9 days ago          Up 2 days                                                            compiler
```

Next get a shell inside the container:

```
$ docker exec -it autolab bash
root@be56be775428:/home/app/webapp# 
```

By default we are in the project directory. Navigate to the `logs` directory and `cat` or `tail` `production.log`. This contains logs from the Autolab application itself.

```
root@be56be775428:/home/app/webapp# cd log
root@be56be775428:/home/app/webapp/log# tail -f -n +1 production.log 
```

We can also check out our Nginx logs in `/var/log/nginx/`:

```
root@be56be775428:/home/app/webapp/log# cd /var/log/nginx/
root@be56be775428:/var/log/nginx# ls
access.log  error.log
```

### Accessing the Rails console
Obtain a shell in the `autolab` container as described [previously](#checking-autolab-logs), and do `RAILS_ENV=production bundle exec rails c`:

```
root@be56be775428:/home/app/webapp# RAILS_ENV=production bundle exec rails c
Loading production environment (Rails 5.2.0)
2.6.6 :001 > User.all.count
 => 1
```

In the example above, if you performed `make create-user` you should have at least one user in your database. If there are errors connecting to a database here it is likely that the database was misconfigured.

### Checking Tango Logs
Get a shell in the Tango instance, similar to the instructions mentioned [previously](#checking-autolab-logs). The logs are stored in the parent folder (`/opt/TangoService`) of the project directory:

```
$ docker exec -it tango bash
root@a5b77b5267b1:/opt/TangoService/Tango# cd ..
root@a5b77b5267b1:/opt/TangoService# ls
Tango  tango_job_manager_log.log  tango_log.log
root@a5b77b5267b1:/opt/TangoService# tail -f -n +1 tango_job_manager_log.log tango_log.log 
```

### Troubleshooting Autolab/Tango Connection
In the Autolab container, try to curl Tango:

```
root@be56be775428:/home/app/webapp# curl tango:3000
Hello, world! RESTful Tango here!
```

In the Tango container, try to curl Autolab:

```
root@a5b77b5267b1:/opt/TangoService/Tango# curl autolab
<html>
<head><title>301 Moved Permanently</title></head>
<body bgcolor="white">
<center><h1>301 Moved Permanently</h1></center>
<hr><center>nginx/1.14.0 (Ubuntu)</center>
</body>
</html>
```

### Permission issues in Autolab
Run `make set-perms` again

### Restarting Autolab Passenger Server
This is useful when you might want to test out some code change within the Autolab container without having to rebuild everything again. These changes can be applied by just restarting the Passenger service that is serving Autolab.

Run `passenger-config restart-app`:

```
root@8b56488b3fb6:/home/app/webapp# passenger-config restart-app
Please select the application to restart.
Tip: re-run this command with --help to learn how to automate it.
If the menu doesn't display correctly, press '!'

 ‣   /home/app/webapp (production)
     Cancel

Restarting /home/app/webapp (production)
```