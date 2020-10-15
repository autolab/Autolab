This page documents the interface for Tango's Virtual Machine Management Systems' (VMMSs) API and instructions for setting up VMMSs. See [the vmms directory](https://github.com/autolab/Tango/tree/master/vmms) in Tango for example implementations.

## API

The functions necessary to implement the API are documented here. Note that for certain implementations, some of these methods will be no-ops since the VMMS doesn't require any particular instructions to perform the specified actions. Furthermore, throughout this document, we use the term "VM" liberally to represent any container-like object on which Tango jobs may be run.

### initializeVM

```python
initializeVM(self, vm)
```

Creates a new VM instance for the VMMS based on the fields of `vm`, which is a `TangoMachine` object defined in `tangoObjects.py`.

### waitVM

```python
waitVM(self, vm, max_secs)
```

Waits at most `max_secs` for a VM to be ready to run jobs. Returns an error if the VM is not ready after `max_secs`.

### copyIn

```python
copyIn(self, vm, inputFiles)
```

Copies the input files for a job into the VM. `inputFiles` is a list of `InputFile` objects defined in `tangoObjects.py`. For each `InputFile` object, `file.localFile` is the name of the file on the Tango host machine and `file.destFile` is what the name of the file should be on the VM.

### runJob

```python
runJob(self, vm, runTimeout, maxOutputFileSize)
```

Runs the autodriver binary on the VM. The autodriver runs `make` on the VM (which in turn runs the job via the `Makefile` that was provided as a part of the input files for the job). The output from the autodriver most likely should be redirected to some feedback file to be used in the next method of the API.

### copyOut

```python
copyOut(self, vm, destFile)
```

Copies the output file for the job out of the VM into `destFile` on the Tango host machine.

### destroyVM

```python
destroyVM(self, vm)
```

Removes a VM from the Tango system.

### safeDestroyVM

```python
safeDestroyVM(self, vm)
```

Removes a VM from the Tango system and makes sure that it has been removed.

### getVMs

```python
getVMs(self)
```

Returns a complete list of VMs associated with this Tango system.

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
