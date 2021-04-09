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
-   [Tango Architecture Overview](https://autolab.github.io/2015/04/making-backend-scalable/)
-   [Deploying Tango](/installation/tango/#production-installation)
