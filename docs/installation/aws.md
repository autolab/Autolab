# AWS Installation

The AWS installation is a beta installation and deployment method. It uses the same underlying systems and services as the Docker Compose method but runs jobs in EC2 containers instead of docker containers. This provides better isolation and scalability for autograding workloads.

If you are stuck or find issues with the installation process you can either file an issue on our Github repository, or join our Slack [here](https://communityinviter.com/apps/autolab/autolab-project) and let us know and we will try our best to help. Also see the [debugging](#debugging-your-deployment) section for tips on how to diagnose problems and check out the [troubleshooting](#troubleshooting) section if you run into any issues.

## Prerequisites

Before you begin, ensure you have:

- An active AWS account with billing enabled
- Access to the AWS console (CloudFormation, EC2, VPC, and IAM services)
- Basic familiarity with AWS services
- Appropriate IAM permissions to create CloudFormation stacks, EC2 instances, security groups, and elastic IPs

## Installation

### Step 1: Clone the Docker Repository

First, clone the autolab-docker repository to get the necessary CloudFormation templates:

    :::bash
    git clone --recurse-submodules -j8 https://github.com/autolab/docker.git autolab-docker
    cd autolab-docker

### Step 2: Create an EC2 Key Pair

1. Navigate to the AWS EC2 console
2. Go to **Network & Security** > **Key Pairs**
3. Click **Create key pair**
4. Give it a meaningful name (e.g., `autolab-keypair`)
5. Select your preferred key pair type (RSA recommended)
6. Choose a file format (.pem for OpenSSH, .ppk for PuTTY)
7. Click **Create key pair** and save the private key file securely

**Important:** Keep your private key file safe. You'll need it to SSH into your EC2 instances.

### Step 3: Create the AMI Stack

This step creates a base EC2 instance that will be used to generate a custom AMI for running Autolab jobs.

1. Navigate to the **AWS CloudFormation** console
2. Click **Create stack** > **With new resources (standard)**
3. Under **Specify template**, select **Upload a template file**
4. Click **Choose file** and upload the `ami.yml` file from the autolab-docker repository
5. Click **Next**
6. Configure the stack parameters:
   - **Stack name**: Enter a descriptive name (e.g., `autolab-ami-stack`)
   - **KeyName**: Select the key pair you created in Step 2
   - **InstanceType**: Leave as default, or select a type based on your needs (`t2.micro` is suitable for testing)
7. Click **Next** through the remaining configuration pages
8. Review your settings and click **Create stack**
9. Wait for the stack creation to complete (Status: CREATE_COMPLETE)

### Step 4: Create an AMI from the Instance

1. In the CloudFormation console, select your AMI stack
2. Go to the **Resources** tab
3. Click on the Physical ID of the EC2 instance to navigate to the EC2 console
4. Select the instance and ensure it's in the "running" state
5. Click **Actions** > **Image and templates** > **Create image**
6. Configure the AMI:
   - **Image name**: Choose a descriptive name (e.g., `autolab-autograding-ami`)
   - **Image description**: Add a description (e.g., "Autolab autograding environment")
   - Leave other settings as default
7. Click **Create image**
8. Navigate to **EC2** > **Images** > **AMIs** and wait for the AMI state to become "available"
9. Note the **AMI ID** (format: ami-xxxxxxxxxxxxxxxxx) - you'll need this in the next step

### Step 5: Update the Marketplace Template

1. Open the `marketplace.yml` file in a text editor
2. Locate line 146 (or search for `ImageId` in the AMI mappings section)
3. Replace the AMI ID with the one you created in Step 4, ensuring you update it for the correct AWS region
4. Save the file

Example:
```yaml
Mappings:
  RegionMap:
    us-east-1:
      ImageId: ami-0123456789abcdef0  # Replace with your AMI ID
```

### Step 6: Create an Elastic IP

An Elastic IP provides a static public IP address for your Autolab deployment.

1. Navigate to the **EC2** console
2. Go to **Network & Security** > **Elastic IPs**
3. Click **Allocate Elastic IP address**
4. Leave the settings as default (Amazon's pool of IPv4 addresses)
5. Click **Allocate**
6. Note the allocated **Elastic IP address** - you'll need this in the next step

### Step 7: Deploy the Marketplace Stack

This stack creates the main Autolab infrastructure, including the application server and autograding environment.

1. Navigate to the **AWS CloudFormation** console
2. Click **Create stack** > **With new resources (standard)**
3. Under **Specify template**, select **Upload a template file**
4. Click **Choose file** and upload the `marketplace.yml` file (the one you updated in Step 5)
5. Click **Next**
6. Configure the stack parameters:
   - **Stack name**: Choose a descriptive name (e.g., `autolab-production-stack`)
   - **ElasticIP**: Enter the Elastic IP address from Step 6
   - **KeyName**: Select the same key pair you created in Step 2
   - Configure any other parameters as needed (database passwords, instance types, etc.)
7. Click **Next** through the configuration pages
8. On the review page, check the box acknowledging that CloudFormation might create IAM resources
9. Click **Create stack**
10. Wait for the stack creation to complete (Status: CREATE_COMPLETE) - this may take 10-15 minutes

### Step 8: Configure DNS (Optional but Recommended)

Point your domain name to the Elastic IP address:

1. Log into your DNS provider's console
2. Create an A record pointing your domain (e.g., `autolab.yourdomain.com`) to the Elastic IP from Step 6
3. Wait for DNS propagation (this can take up to 48 hours, but is typically much faster)

### Step 9: Initial Setup

Once the marketplace stack is created, you need to complete the initial Autolab configuration:

1. SSH into your Autolab instance:

        :::bash
        ssh -i /path/to/your-keypair.pem ec2-user@<your-elastic-ip>

2. Navigate to the Autolab directory:

        :::bash
        cd /path/to/autolab

3. Perform database migrations:

        :::bash
        docker compose exec autolab bundle exec rake db:migrate

4. Create an administrative user:

        :::bash
        docker compose exec autolab bundle exec rake autolab:create_user

5. Follow the prompts to set up your admin account

### Step 10: Access Autolab

You can now access Autolab by navigating to:

- `http://<your-elastic-ip>` (if not using a domain)
- `http://autolab.yourdomain.com` (if you configured DNS)

Log in with the administrative credentials you created in Step 9.

## Configuring TLS/SSL

For production deployments, it's strongly recommended to configure TLS/SSL to encrypt traffic. Follow the same TLS configuration steps outlined in the [Docker Compose installation guide](/installation/docker-compose/#configuring-tlsssl).

The key differences for AWS:

1. Ensure that your AWS Security Groups allow inbound traffic on ports 80 and 443
2. If using Let's Encrypt, ensure your domain's DNS A record points to your Elastic IP
3. The SSL certificate files should be placed in the same locations as documented for Docker Compose

## Post-Installation Configuration

### Security Groups

Ensure your EC2 security groups allow the following inbound traffic:

- **Port 22 (SSH)**: For administrative access (restrict to your IP for security)
- **Port 80 (HTTP)**: For web access
- **Port 443 (HTTPS)**: For secure web access (if using TLS)
- **Port 3000** (if applicable): For Tango worker communication

### Autograding Configuration

Configure Tango to use EC2 for autograding jobs by updating the Tango configuration file. Refer to the [Tango documentation](/installation/tango/) for detailed configuration options.

### Mailing Setup

Configure email functionality for user registration and password resets by following the [mailing setup guide](/installation/mailing/). You can use Amazon SES, which integrates well with AWS deployments.

## Updating Your AWS Deployment

To update your Autolab instance:

1. SSH into your instance
2. Pull the latest changes:

        :::bash
        cd /path/to/autolab-docker
        git pull
        git submodule update --init --recursive

3. Rebuild the Docker images:

        :::bash
        docker compose build

4. Restart the services:

        :::bash
        docker compose down
        docker compose up -d

5. Run any pending database migrations:

        :::bash
        docker compose exec autolab bundle exec rake db:migrate

## Debugging Your Deployment

### Viewing Logs

Check Docker container logs:

    :::bash
    docker compose logs autolab
    docker compose logs tango

View CloudFormation stack events:

1. Navigate to the CloudFormation console
2. Select your stack
3. Go to the **Events** tab to see detailed creation/update events

### Common Issues

**Issue**: Cannot SSH into EC2 instance

- Ensure your security group allows SSH (port 22) from your IP
- Verify you're using the correct key pair
- Check that the instance is in the "running" state

**Issue**: Autolab web interface not accessible

- Verify the Elastic IP is properly associated with your instance
- Check security group rules for ports 80 and 443
- Ensure Docker containers are running: `docker compose ps`
- Check Nginx logs: `docker compose logs autolab`

**Issue**: AMI creation fails

- Ensure the EC2 instance is running before creating the AMI
- Verify you have sufficient permissions to create AMIs
- Check if you've reached the AMI limit in your AWS account

## Troubleshooting

### Stack Creation Fails

If CloudFormation stack creation fails:

1. Go to the CloudFormation console
2. Select the failed stack
3. Check the **Events** tab for error messages
4. Common issues include:
   - Invalid key pair name
   - Insufficient IAM permissions
   - Resource limits exceeded (e.g., max number of Elastic IPs)
   - Invalid AMI ID in the template

### Database Connection Issues

If you encounter database connectivity problems:

    :::bash
    # Check if MySQL container is running
    docker compose ps mysql
    
    # View MySQL logs
    docker compose logs mysql
    
    # Test database connection
    docker compose exec autolab bundle exec rake db:version

### Performance Optimization

For better performance on AWS:

1. **Use appropriate instance types**: Consider memory-optimized instances (e.g., r5 series) for larger deployments
2. **Enable EBS optimization**: Improve disk I/O performance
3. **Use RDS for the database**: For production deployments, consider using Amazon RDS instead of a containerized MySQL instance
4. **Configure CloudWatch**: Set up monitoring and alerts for your EC2 instances

## Cost Considerations

Running Autolab on AWS incurs costs. To optimize:

- Use reserved instances or savings plans for long-term deployments
- Stop instances during periods of non-use (e.g., between semesters)
- Monitor your usage with AWS Cost Explorer
- Set up billing alerts to avoid unexpected charges
- Use t3/t4 burstable instances for variable workloads

## Backup and Disaster Recovery

### Regular Backups

Create regular snapshots of your EBS volumes:

1. Navigate to EC2 > Volumes
2. Select the volume(s) attached to your Autolab instance
3. Actions > Create snapshot
4. Schedule automated snapshots using AWS Backup or Data Lifecycle Manager

### Database Backups

Regularly backup your Autolab database:

    :::bash
    docker compose exec mysql mysqldump -u root -p autolab > autolab_backup_$(date +%Y%m%d).sql

Store backups in S3 for durability:

    :::bash
    aws s3 cp autolab_backup_*.sql s3://your-backup-bucket/

## Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Autolab Docker Repository](https://github.com/autolab/docker)
- [Autolab GitHub Issues](https://github.com/autolab/Autolab/issues)
- [Autolab Slack Community](https://communityinviter.com/apps/autolab/autolab-project)

## Next Steps

After completing the installation:

1. Fill out [this form](https://docs.google.com/forms/d/e/1FAIpQLSctfi3kwa03yuCuLgGF7qS_PItfk__1s80twhVDiKGQHvqUJg/viewform?usp=sf_link) to join the Autolab registry
2. Review the [Guide for Instructors](/instructors)
3. Learn how to create assessments with the [Guide for Lab Authors](/lab)
4. Configure [LTI integration](/installation/lti_integration/) if needed
5. Set up [GitHub integration](/installation/github_integration/) for seamless submission workflows


