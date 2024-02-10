# Tango Installation
This guide provides instructions for installing Tango on either a [development environment](#development-installation) or a [production environment](#production-installation).

## Development Installation

This guide shows how to setup Tango in a **development environment**. Use the [production installation](#production-installation) guide for installing in a **production environment**.

1. Obtain the source code.

        :::bash
        git clone https://github.com/autolab/Tango.git; cd Tango

2. Install Redis following <a href="http://redis.io/topics/quickstart" target="_blank">this guide</a>. By default, Tango uses Redis as a stateless job queue. Learn more <a href="https://autolab.github.io/2015/04/making-backend-scalable/" target="_blank">here</a>.

3. Create a `config.py` file from the given template.

        :::bash
        cp config.template.py config.py

4. Create the course labs directory where job's output files will go, organized by key and lab name:

        :::bash
        mkdir courselabs

    By default the `COURSELABS` option in `config.py` points to the `courselabs` directory in the Tango directory.
    Change this to specify another path if you wish.

5. Set up a VMMS for Tango to use.

    -   [Docker](#docker-vmms-setup) (**recommended**)
    -   [Amazon EC2](#amazon-ec2-vmms-setup)
    -   TashiVMMS (deprecated)


6. Run the following commands to setup the Tango dev environment inside the Tango directory. <a href="https://pip.pypa.io/en/stable/installing/" target="_blank">Install pip</a> if needed.

        :::bash
        pip install virtualenv
        virtualenv env
        source env/bin/activate
        pip install -r requirements.txt
        mkdir volumes

7. If you are using Docker, set `DOCKER_VOLUME_PATH` in `config.py` to be the path to the `volumes` directory you just created.

        :::bash
        DOCKER_VOLUME_PATH = "/path/to/Tango/volumes/"


8. Start Redis by running the following command:

        :::bash
        redis-server

9. Run the following command to start the server (producer). If no port is given, the server will run on the port specified in `config.py` (default: 3000):

        :::bash
        python restful_tango/server.py <port>

    Open another terminal window and start the job manager (consumer):

        :::bash
        python jobManager.py

    For more information on the job producer/consumer model check out our <a href="https://autolab.github.io/2015/04/making-backend-scalable/" target="_blank">blog post</a>.

10. Ensure Tango is running:

        :::bash
        curl localhost:<port>
        # Hello, world! RESTful Tango here!

11. You can test the Tango setup using the [command line client](/tango-cli/).

12. If you are using Tango with Autolab, you have to configure Autolab to use Tango. Go to your Autolab directory and enter the following commands:

        :::bash
        cp config/autogradeConfig.rb.template config/autogradeConfig.rb
    
    Then in your Autolab installation's `.env` file, fill in the correct info for your Tango deployment, mainly the following:

        :::ruby
        # Hostname for Tango RESTful API
        RESTFUL_HOST = "foo.bar.edu" #(if you are running Tango locally, then it is just "localhost")

        # Port for Tango RESTful API
        RESTFUL_PORT = "3000"

        # Key for Tango RESTful API
        RESTFUL_KEY = "test" # change this in production to a secret phrase

    Note that by default Autolab also uses a default port of `3000`, so be sure to change the port if you are developing on `localhost`.

    

13. See below for instructions on how to deploy Tango in a standalone production environment.

## Production Installation

This is a guide to setup a fully self-sufficient Tango deployment environment out-of-the-box using Docker. The suggested deployment pattern for Tango uses Nginx as a proxy and Supervisor as a process manager for Tango and all its dependencies. All requests to Nginx are rerouted to a Tango process.

### Details
-   Nginx default port - 8600
-   Tango ports - 8610, 8611
-   Redis port - 6379
-   You can change any of these in the respective config files in `deployment/config/` before you build the `tango_deployment` image.

### Steps
1. Clone the Tango repo

        :::bash
        $ git clone https://github.com/autolab/Tango.git; cd Tango

2. Create a `config.py` file from the given template.  
      
        :::bash
        $ cp config.template.py config.py

3. Modify `DOCKER_VOLUME_PATH` in `config.py` as follows: 
	
        :::bash
        DOCKER_VOLUME_PATH = '/opt/TangoService/Tango/volumes/'

4. Install docker on the host machine by following instructions on the <a href="https://docs.docker.com/installation/" target="_blank">docker installation page</a>.  
Then give yourself permissions to run docker without root (need to relog in after):

        :::bash
        $ sudo usermod -aG docker $USER

5. Ensure docker is running:

        :::bash
        $ sudo service docker start
        $ docker ps
        # CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                    NAMES

6. Run the following command to build the Tango deployment image.

        :::bash
        $ docker build --tag="tango_deployment" .

7. Ensure the image was built by running.

        :::bash
        $ docker images
        # REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
        # tango_deployment    latest              3c0d4f4b4958        2 minutes ago       742.6 MB
        # ubuntu              15.04               d1b55fd07600        4 minutes ago       131.3 MB

8. Run the following command to access the image in a container with a bash shell. The `-p` flag will map `nginxPort` on the docker container to `localPort` (8610 recommended) on your local machine (or on the VM that docker is running in on the local machine) so that Tango is accessible from outside the docker container.
      
        :::bash
        $ docker run --privileged -p <localPort>:<nginxPort> -it tango_deployment /bin/bash

9. Set up a VMMS for Tango within the Docker container.

    - [Docker](#docker-vmms-setup) (**recommended**)
    - [Amazon EC2](#amazon-ec2-vmms-setup)

10. Run the following command to start supervisor, which will then start Tango and all its dependencies.

        :::bash
        $ service supervisor start

11. Check to see if Tango is responding to requests
      
        :::bash
        $ curl localhost:8610 # Hello, world! RESTful Tango here!

12. Once you have a VMMS set up, leave the tango_deployment container by typing `exit` and once back in the host shell run the following command to get the name of your production container.

        :::bash
        $ docker ps -as
        # CONTAINER ID        IMAGE               COMMAND               NAMES               SIZE
        # c704d45c3737    tango_deployment       "/bin/bash"            erwin             40.26 MB

        The container created in this example has the name `erwin`.

13. The name of the production container can be changed by running the following command and will be used to run the container and create services.

        :::bash
        $ docker rename <old_name> <new_name>

14. To reopen the container once it has been built use the following command. This will reopen the interactive shell within the container and allow for configuration of the container after its initial run.

        :::bash
        $ docker start erwin
        $ docker attach erwin

15. Once the container is set up with the autograding image, and the VMMS configured with any necessary software/environments needed for autograding (java, perl, etc), some configurations need to be changed to make the container daemon ready. Using the `CONTAINER ID` above, use the following commands to modify that containers `config.v2.json` file.

        :::bash
        $ sudo ls  /var/lib/docker/containers
        c704d45c37372a034cb97761d99f6f3f362707cc23d689734895e017eda3e55b
        $ sudo vim /var/lib/docker/containers/c704d45c37372a034cb97761d99f6f3f362707cc23d689734895e017eda3e55b/config.v2.json

16. Edit the "Path" field in the config.v2.json file from "/bin/bash" to "/usr/bin/supervisord" and save the file. Run the following commands to verify the changes were successful. The COMMAND field should now be "/usr/bin/supervisord"

        :::bash
        $ service docker restart
        $ docker ps -as
        # CONTAINER ID        IMAGE               COMMAND               NAMES               SIZE
        # c704d45c3737    tango_deployment   "/usr/bin/supervisord"     erwin             40.26 MB

17. At this point when the container is started, the environment is fully set up and will no longer be an interactive shell. Instead, it will be the supervisor service that starts Tango and all its dependencies. Test this with the following commands and ensure Tango is functioning properly.

        :::bash
        $ docker start erwin
        # (Test tango environment)
        $ docker stop erwin

18. Test the setup by running sample jobs using [the testing guide](/tango-cli/).

    **The following steps are optional and should only be used if you would like the Tango container to start on system boot.**

19. To ensure Tango starts with the system in the production environment, the container needs to be configured as a service. Below is a sample service config file that needs to be changed to suit your environment and placed in `/etc/systemd/system/`. The file should be named `<name>.service`. For this example, it is `erwin.service`.

        :::bash
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

20. Test and ensure the service was set up correctly. The service should start successfully and remain running.

        :::bash
        $ systemctl daemon-reload
        $ service erwin start
        $ service erwin status

21. Enable the service at system startup and reboot and ensure it starts with the host.

        :::bash
        $ systemctl enable erwin.service
        $ sudo reboot
        # (Server Reboots)
        $ service erwin status

## Docker VMMS Setup

This is a guide to set up Tango to run jobs inside Docker containers.

1. Install docker on host machine by following instructions on the <a href="https://docs.docker.com/installation/" target="_blank">docker installation page</a>.  
Then give yourself permissions to run docker without root (need to relog in after):

        :::bash
        sudo usermod -aG docker $USER

2. Ensure docker is running:
      
        :::bash
        sudo service docker start
        docker ps # CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES

3. Build base Docker image from root Tango directory.

        :::bash
        cd path/to/Tango
        docker build -t autograding_image vmms/
        docker images autograding_image    # Check if image built

4. Update `VMMS_NAME` in `config.py`.

        :::python
        # in config.py
        VMMS_NAME = "localDocker"

## Amazon EC2 VMMS Setup

This is a guide to set up Tango to run jobs on an Amazon EC2 VM.

1. Create an <a href="https://aws.amazon.com/" target="_blank">AWS Account</a> or use an existing one.

2. Obtain your `access_key_id` and `secret_access_key` by following the instructions <a href="http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys" target="_blank">here</a>.

3. Add AWS Credentials to a file called `~/.boto` using the following format:

        :::bash
        [Credentials]
            aws_access_key_id = MYAMAZONTESTKEY12345
            aws_secret_access_key = myawssecretaccesskey12345

    Tango uses the <a href="http://boto.cloudhackers.com/en/latest/" target="_blank">Boto</a> Python package to interface with Amazon Web Services

4. In the AWS EC2 console, create an Ubuntu 14.04+ EC2 instance and save the `.pem` file in a safe location.

5. Copy the directory and contents of `autodriver/` in the Tango repo into the EC2 VM. For more help connecting to the EC2 instance follow <a href="http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html#AccessingInstancesLinuxSCP" target="_blank">this guide</a>.

        :::bash
        chmod 400 /path/my-key-pair.pem
        scp -i /path/my-key-pair.pem -r autodriver/ ubuntu@<ec2-host-name>.compute-1.amazonaws.com:~/

    The autodriver is used as a sandbox environment to run the job inside the VM. It limits Disk I/O, Disk Usage, monitors security, and controls other valuable `sudo` level resources.

6. In the EC2 VM, compile the autodriver.

        :::bash
        $ cd autodriver/
        $ make clean; make
        $ cp -p autodriver /usr/bin/autodriver

7. Create the `autograde` Linux user and directory. All jobs will be run under this user.

        :::bash
        $ useradd autograde
        $ mkdir autograde
        $ chown autograde autograde
        $ chown :autograde autograde

8. In the AWS EC2 console, create an AMI image from your EC2 VM. Use <a href="http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html#how-to-create-ebs-ami" target="_blank">this guide</a> to create a custom AMI.

9. Exit the EC2 instance and edit the following values in `config.py` in the Tango directory.

        :::bash
        # VMMS to use. Must be set to a VMMS implemented in vmms/ before
        # starting Tango.  Options are: "localDocker", "distDocker",
        # "tashiSSH", and "ec2SSH"
        VMMS_NAME = "ec2SSH"
        ######
        # Part 5: EC2 Constants
        #
        EC2_REGION = 'us-east-1'             # EC2 Region
        EC2_USER_NAME = 'ubuntu'             # EC2 username
        DEFAULT_AMI = 'ami-4c99c35b'         # Custom AMI Id
        DEFAULT_INST_TYPE = 't2.micro'       # Instance Type
        DEFAULT_SECURITY_GROUP = 'autolab-autograde-ec2'  # Security Group with full access to EC2
        SECURITY_KEY_PATH = '/path/to/my-key-pair.pem'    # Absolute path to my-key-pair.pem
        DYNAMIC_SECURITY_KEY_PATH = ''       # Leave blank
        SECURITY_KEY_NAME = 'my-key-pair'    # Name of the key file. Ex: if file name is 'my-key-pair.pem', fill value with 'my-key-pair'
        TANGO_RESERVATION_ID = '1'           # Leave as 1
        INSTANCE_RUNNING = 16                # Status code of a running instance, leave as 16

10. You should now be ready to run Tango jobs on EC2! Use the [Tango CLI](/tango-cli/) to test your setup.