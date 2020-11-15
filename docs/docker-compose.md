# Autolab + Tango Docker Compose Installation

The Autolab Docker Compose installation is a production-ready installation and deployment method. It uses a MySQL database for the Autolab deployment, and comes with SSL support. This is now the preferred way of installing Autolab.

The Docker Compose installation method is relatively new and so you may likely run into issues. If you are stuck or find issues with the installation process please join our Slack [here](https://autolab-slack.herokuapp.com/) and let us know and we will try our best to help. Also see the [debugging](#debugging) section for tips on how to diagnose problems.

## Installation
Under Construction

## Configuring SSL
Under Construction

## Updating
Under Construction

## Debugging
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
