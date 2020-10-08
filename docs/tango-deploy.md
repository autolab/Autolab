# Deploying Standalone Tango

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
