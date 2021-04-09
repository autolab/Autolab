# Tango Installation

This guide provides instructions for installing Tango on either a [development environment](#development-installation) or a [production environment](#production-installation).

# Development Installation

This guide shows how to setup Tango in a **development environment**. Use the [production installation](#production-installation) guide for installing in a **production environment**.

1.  Obtain the source code.

        :::bash
        git clone https://github.com/autolab/Tango.git; cd Tango

2.  Install Redis following [this guide](http://redis.io/topics/quickstart). By default, Tango uses Redis as a stateless job queue. Learn more [here](https://autolab.github.io/2015/04/making-backend-scalable/).

3.  Create a `config.py` file from the given template.

        :::bash
        cp config.template.py config.py

4.  Create the course labs directory where job's output files will go, organized by key and lab name:

        :::bash
        mkdir courselabs

    By default the `COURSELABS` option in `config.py` points to the `courselabs` directory in the Tango directory.
    Change this to specify another path if you wish.

5.  Set up a VMMS for Tango to use.

    -   [Docker](/tango-vmms/#docker-vmms-setup) (**recommended**)
    -   [Amazon EC2](/tango-vmms/#amazon-ec2-vmms-setup)
    -   TashiVMMS (deprecated)


6.  Run the following commands to setup the Tango dev environment inside the Tango directory. [Install pip](https://pip.pypa.io/en/stable/installing/) if needed.

        :::bash
        $ pip install virtualenv
        $ virtualenv .
        $ source bin/activate
        $ pip install -r requirements.txt
        $ mkdir volumes

7.  If you are using Docker, set `DOCKER_VOLUME_PATH` in `config.py` to be the path to the `volumes` directory you just created.

        :::bash
        DOCKER_VOLUME_PATH = "/path/to/Tango/volumes/"


8.  Start Redis by running the following command:

        :::bash
        $ redis-server

9.  Run the following command to start the server (producer). If no port is given, the server will run on the port specified in `config.py` (default: 3000):

        :::bash
        python restful-tango/server.py <port>

    Open another terminal window and start the job manager (consumer):

        :::bash
        python jobManager.py

    For more information on the job producer/consumer model check out our [blog post](https://autolab.github.io/2015/04/making-backend-scalable/)

10.  Ensure Tango is running:

        :::bash
        $ curl localhost:<port>
        # Hello, world! RESTful Tango here!

11. You can test the Tango setup using the [command line client](/tango-cli/).

12. If you are using Tango with Autolab, you have to configure Autolab to use Tango. Go to your Autolab directory and enter the following commands:

        :::bash
        cp config/autogradeConfig.rb.template config/autogradeConfig.rb

    Fill in the correct info for your Tango deployment, mainly the following:

        :::ruby
        # Hostname for Tango RESTful API
        RESTFUL_HOST = "foo.bar.edu" #(if you are running Tango locally, then it is just "localhost")

        # Port for Tango RESTful API
        RESTFUL_PORT = "3000"

        # Key for Tango RESTful API
        RESTFUL_KEY = "test"

13. See below for instructions on how to deploy Tango in a standalone production environment.




# Production Installation

This is a guide to setup a fully self-sufficient Tango deployment environment out-of-the-box using Docker. The suggested deployment pattern for Tango uses Nginx as a proxy and Supervisor as a process manager for Tango and all its dependencies. All requests to Nginx are rerouted to a Tango process.

## Details

-   Nginx default port - 8600
-   Tango ports - 8610, 8611
-   Redis port - 6379
-   You can change any of these in the respective config files in `deployment/config/` before you build the `tango_deployment` image.

## Steps

1.  Clone the Tango repo

        :::sh
        $ git clone https://github.com/autolab/Tango.git; cd Tango

2.  Create a `config.py` file from the given template.  
      
        :::sh
        $ cp config.template.py config.py

3.  Modify `DOCKER_VOLUME_PATH` in `config.py` as follows: 
	
        :::sh
        DOCKER_VOLUME_PATH = '/opt/TangoService/Tango/volumes/'

4.  Install docker on the host machine by following instructions on the [docker installation page](https://docs.docker.com/installation/). Ensure docker is running:

        :::sh
        $ docker ps
        # CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                    NAMES

5.  Run the following command to build the Tango deployment image.

        :::sh
        $ docker build --tag="tango_deployment" .

6.  Ensure the image was built by running.

        :::sh
        $ docker images
        # REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
        # tango_deployment    latest              3c0d4f4b4958        2 minutes ago       742.6 MB
        # ubuntu              15.04               d1b55fd07600        4 minutes ago       131.3 MB

7.  Run the following command to access the image in a container with a bash shell. The `-p` flag will map `nginxPort` on the docker container to `localPort` (8610 recommended) on your local machine (or on the VM that docker is running in on the local machine) so that Tango is accessible from outside the docker container.
      
        :::sh
        $ docker run --privileged -p <localPort>:<nginxPort> -it tango_deployment /bin/bash

8.  Set up a VMMS for Tango within the Docker container.

    - [Docker](/tango-vmms/#docker-vmms-setup) (**recommended**)
    - [Amazon EC2](/tango-vmms/#amazon-ec2-vmms-setup)

9.  Run the following command to start supervisor, which will then start Tango and all its dependencies.

        :::sh
        $ service supervisor start

10.  Check to see if Tango is responding to requests
      
        :::sh
        $ curl localhost:8610 # Hello, world! RESTful Tango here!

11. Once you have a VMMS set up, leave the tango_deployment container by typing `exit` and once back in the host shell run the following command to get the name of your production container.

        :::sh
        $ docker ps -as
        # CONTAINER ID        IMAGE               COMMAND               NAMES               SIZE
        # c704d45c3737    tango_deployment       "/bin/bash"            erwin             40.26 MB

        The container created in this example has the name `erwin`.

12. The name of the production container can be changed by running the following command and will be used to run the container and create services.

        :::sh
        $ docker rename <old_name> <new_name>

13. To reopen the container once it has been built use the following command. This will reopen the interactive shell within the container and allow for configuration of the container after its initial run.

        :::sh
        $ docker start erwin
        $ docker attach erwin

14. Once the container is set up with the autograding image, and the VMMS configured with any necessary software/environments needed for autograding (java, perl, etc), some configurations need to be changed to make the container daemon ready. Using the `CONTAINER ID` above, use the following commands to modify that containers `config.v2.json` file.

        :::sh
        $ sudo ls  /var/lib/docker/containers
        c704d45c37372a034cb97761d99f6f3f362707cc23d689734895e017eda3e55b
        $ sudo vim /var/lib/docker/containers/c704d45c37372a034cb97761d99f6f3f362707cc23d689734895e017eda3e55b/config.v2.json

15. Edit the "Path" field in the config.v2.json file from "/bin/bash" to "/usr/bin/supervisord" and save the file. Run the following commands to verify the changes were successful. The COMMAND field should now be "/usr/bin/supervisord"

        :::sh
        $ service docker restart
        $ docker ps -as
        # CONTAINER ID        IMAGE               COMMAND               NAMES               SIZE
        # c704d45c3737    tango_deployment   "/usr/bin/supervisord"     erwin             40.26 MB

16. At this point when the container is started, the environment is fully set up and will no longer be an interactive shell. Instead, it will be the supervisor service that starts Tango and all its dependencies. Test this with the following commands and ensure Tango is functioning properly.

        :::sh
        $ docker start erwin
        # (Test tango environment)
        $ docker stop erwin

17. Test the setup by running sample jobs using [the testing guide](/tango-cli/).

    **The following steps are optional and should only be used if you would like the Tango container to start on system boot.**

18. To ensure Tango starts with the system in the production environment, the container needs to be configured as a service. Below is a sample service config file that needs to be changed to suit your environment and placed in `/etc/systemd/system/`. The file should be named `<name>.service`. For this example, it is `erwin.service`.

        :::sh
        [Unit]
        Description=Docker Service Managing Tango Container
        Requires=docker.service
        After=docker.service

        [Service]
        Restart=always
        ExecStart=/usr/bin/docker start -a erwin
        ExecStop=/usr/bin/docker stop -t 2 erwin

        [Install]
        WantedBy=default.target

19. Test and ensure the service was set up correctly. The service should start successfully and remain running.

        :::sh
        $ systemctl daemon-reload
        $ service erwin start
        $ service erwin status

20. Enable the service at system startup and reboot and ensure it starts with the host.

        :::sh
        $ systemctl enable erwin.service
        $ sudo reboot
        # (Server Reboots)
        $ service erwin status