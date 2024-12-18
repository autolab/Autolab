The installation process comprises installing both Autolab and Tango (the autograding backend). MySQL and Redis will also need to be installed in most use cases.

There are 2 different ways to install Autolab and Tango:

  1. The simplest and fastest way to get up and running is to use our [Docker Compose installation](/installation/docker-compose/), which is ideal for most workloads. Both production-ready and testing deployments are available. This will set-up containers for Autolab, Tango, and other required services.
  2. You can also install Autolab manually. There are instructions for installing Autolab on [Ubuntu 22.04](/installation/ubuntu) and on [Mac OSX 10.11+](/installation/osx). The instructions for [installing Tango manually](/installation/tango) are the same for both environments.

Most of our users prefer the Docker Compose installation method as it is simpler, production-ready, and comes deployed with MySQL and TLS/SSL. 

!!! warning "RAM requirements"
    You may face issues on a machine with less than 2GB of RAM as the gem `sassc` takes a significant amount of RAM to install.