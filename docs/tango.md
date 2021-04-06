# Tango

Tango is a standalone RESTful Web service that runs jobs in virtual machines or containers. It was developed as a distributed grading system for [Autolab](/) and has been extensively used for autograding programming assignments. It is also open source and hosted on [Github](https://www.github.com/autolab/Tango).

<!-- ## Getting Started -->

A brief overview of the Tango respository:

-   `tango.py` - Main tango server
-   `jobQueue.py` - Manages the job queue
-   `jobManager.py` - Assigns jobs to free VMs
-   `worker.py` - Shepherds a job through its execution
-   `preallocator.py` - Manages pools of VMs
-   `vmms/` - VMMS library implementations
-   `restful-tango/` - HTTP server layer on the main Tango

Tango runs jobs in VMs using a high level Virtual Memory Management System (VMMS) API. Tango currently has support for running jobs in [Docker](https://www.docker.com/) containers (**recommended**) or [Amazon EC2](https://aws.amazon.com/ec2).

For more information about the different Tango components, go to the following pages:

-   [REST API docs](/tango-rest/)
-   [VMMS API docs](/tango-vmms/)
-   [Tango Architecture Overview](https://docs.autolabproject.com/2015/04/making-backend-scalable/)
-   [Deploying Tango](/tango-deploy/)

### Installation

This guide shows how to setup Tango in a **development environment**. Use the [deploying Tango](/tango-deploy/) guide for installing in a **production environment**.

1.  Obtain the source code.

        :::bash
        git clone https://github.com/autolab/Tango.git; cd Tango

2.  Install Redis following [this guide](http://redis.io/topics/quickstart). By default, Tango uses Redis as a stateless job queue. Learn more [here](https://docs.autolabproject.com/2015/04/making-backend-scalable/).

3.  Create a `config.py` file from the given template.

        :::bash
        cp config.template.py config.py

4.  Create the course labs directory where job's output files will go, organized by key and lab name:

        :::bash
        mkdir courselabs

    By default the `COURSELABS` option in `config.py` points to the `courselabs` directory in the Tango directory.
    Change this to specify another path if you wish.

5.  Set up a VMMS for Tango to use.

    -   [Docker](#docker-vmms-setup) (**recommended**)
    -   [Amazon EC2](#amazon-ec2-vmms-setup)
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

    For more information on the job producer/consumer model check out our [blog post](https://docs.autolabproject.com/2015/04/making-backend-scalable/)

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

13. To deploy Tango in a standalone production environment, use this [guide](/tango-deploy/)


## Docker VMMS Setup

This is a guide to set up Tango to run jobs inside Docker containers.

1.  Install docker on host machine by following instructions on the [docker installation page](https://docs.docker.com/installation/). Ensure docker is running:
      
    	:::bash
    	$ docker ps # CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES

2.  Build base Docker image from root Tango directory.

        :::sh
        cd path/to/Tango
        docker build -t autograding_image vmms/
        docker images autograding_image    # Check if image built

3.  Update `VMMS_NAME` in `config.py`.

        :::python
        # in config.py
        VMMS_NAME = "localDocker"

## Amazon EC2 VMMS Setup

This is a guide to set up Tango to run jobs on an Amazon EC2 VM.

1.  Create an [AWS Account](https://aws.amazon.com/) or use an existing one.

2.  Obtain your `access_key_id` and `secret_access_key` by following the instructions [here](http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys).

3.  Add AWS Credentials to a file called `~/.boto` using the following format:

        :::bash
        [Credentials]
        	aws_access_key_id = MYAMAZONTESTKEY12345
        	aws_secret_access_key = myawssecretaccesskey12345

    Tango uses the [Boto](http://boto.cloudhackers.com/en/latest/) Python package to interface with Amazon Web Services

4.  In the AWS EC2 console, create an Ubuntu 14.04+ EC2 instance and save the `.pem` file in a safe location.

5.  Copy the directory and contents of `autodriver/` in the Tango repo into the EC2 VM. For more help connecting to the EC2 instance follow [this guide](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html#AccessingInstancesLinuxSCP)

        :::bash
        chmod 400 /path/my-key-pair.pem
        scp -i /path/my-key-pair.pem -r autodriver/ ubuntu@<ec2-host-name>.compute-1.amazonaws.com:~/

    The autodriver is used as a sandbox environment to run the job inside the VM. It limits Disk I/O, Disk Usage, monitors security, and controls other valuable `sudo` level resources.

6.  In the EC2 VM, compile the autodriver.

        :::bash
        $ cd autodriver/
        $ make clean; make
        $ cp -p autodriver /usr/bin/autodriver

7.  Create the `autograde` Linux user and directory. All jobs will be run under this user.

        :::bash
        $ useradd autograde
        $ mkdir autograde
        $ chown autograde autograde
        $ chown :autograde autograde

8.  In the AWS EC2 console, create an AMI image from your EC2 VM. Use [this guide](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html#how-to-create-ebs-ami) to create a custom AMI.

9.  Exit the EC2 instance and edit the following values in `config.py` in the Tango directory.

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
