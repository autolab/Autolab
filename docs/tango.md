# Tango

Tango is a standalone RESTful Web service that runs jobs in virtual machines or containers. It was developed as a distributed grading system for [Autolab](/) and has been extensively used for autograding programming assignments. It is also open source and hosted on [Github](https://www.github.com/autolab/Tango).

## Getting Started

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
