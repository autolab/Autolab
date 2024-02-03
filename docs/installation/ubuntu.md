This page provides instructions on installing Autolab for development on Ubuntu 22.04 LTS. If you encounter any issue along the way, check out [Troubleshooting](/installation/troubleshoot).

1. Upgrade system packages and installing prerequisites

        :::bash
        sudo apt-get update
        sudo apt-get upgrade
        sudo apt-get install build-essential git libffi-dev zlib1g-dev autoconf bison libssl-dev libyaml-dev libreadline-dev libncurses5-dev libgdbm6 libgdbm-dev libmysqlclient-dev libjansson-dev universal-ctags sqlite3 libsqlite3-dev pkg-config

2. Cloning Autolab repo from Github to ~/Autolab

        :::bash
        cd ~/
        git clone https://github.com/autolab/Autolab.git
        cd Autolab

3. Setting up rbenv and ruby-build plugin (You may ignore the message about adding a line to bashrc)

        :::bash
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
        source ~/.bashrc

        ~/.rbenv/bin/rbenv init
        git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build

4. Installing Ruby (Based on ruby version)

        :::bash
        cd Autolab
        rbenv install  `cat .ruby-version`

5. Installing MySQL (If you would just like to test Autolab, then you can skip this step by using SQLite)  
Following instructions from <a href="https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-22-04" target="_blank">How to Install MySQL on Ubuntu</a>

        :::bash
        sudo apt install mysql-server
        sudo service mysql start

        sudo mysql
        mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '<password>';
        mysql> exit;

        sudo mysql_secure_installation
        > There will be a few questions asked during the MySQL setup.
        * Validate Password Plugin? N
        * Remove Anonymous Users? Y
        * Disallow Root Login Remotely? Y
        * Remove Test Database and Access to it? Y
        * Reload Privilege Tables Now? Y

        sudo mysql -u root -p
        mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;
        mysql> exit;

6. (If you are using MySQL) Create a new user with access to `autolab_test` and `autolab_development` databases. Because a password rather than auth_socket is needed, we need to ensure that user uses `mysql_native_password`

        :::bash
        sudo mysql
        mysql> CREATE USER '<username>'@'localhost' IDENTIFIED WITH mysql_native_password BY '<password>';
        mysql> FLUSH PRIVILEGES;
        mysql> exit;

7. Installing Rails

        :::bash
        cd Autolab
        gem install bundler -v $(tail -n1 Gemfile.lock)
        bundle install

    Refer to [Troubleshooting](/installation/troubleshoot) for issues installing gems.

8. Initializing Autolab Configs

        :::bash
        cp config/database.yml.template config/database.yml
        cp config/school.yml.template config/school.yml
        cp config/autogradeConfig.rb.template config/autogradeConfig.rb

    - Edit `school.yml` with your school/organization specific names and emails.
    - Edit `database.yml` with the correct credentials for your chosen database. Refer to [Troubleshooting](/installation/troubleshoot) for any issues and suggested development [configurations](/installation/troubleshoot/#suggested-development-configuration-for-configdatabaseyml).

9. Create a .env file to store Autolab configuration constants

        :::bash
        cp .env.template .env

    If you have not installed Tango yet, you do not need to do anything else in this stage. If you have already installed Tango, you should make sure to fill in the `.env` file with values consistent with Tango's `config.py`

10. Initialize application secrets

        :::bash
        ./bin/initialize_secrets.sh

11. (Using MySQL) Editing Database YML.
Change the <username> and <password> fields in config/database.yml to the username and password that has been set up for the mysql. For example if your username is `user1`, and your password is `123456`, then your yml would be

        :::yml
        development:
            adapter: mysql2
            database: autolab_development
            pool: 5
            username: user1
            password: '123456'
            socket: /var/run/mysqld/mysqld.sock
            host: localhost
            variables:
                sql_mode: NO_ENGINE_SUBSTITUTION

        test:
            adapter: mysql2
            database: autolab_test
            pool: 5
            username: user1
            password: '123456'
            socket: /var/run/mysqld/mysqld.sock
            host: localhost
            variables:
                sql_mode: NO_ENGINE_SUBSTITUTION

12. (Using SQLite) Editing Database YML.
Comment out the configurations meant for MySQL in config/database.yml, and insert the following

        :::yml
        development:
            adapter: sqlite3
            database: db/autolab_development
            pool: 5
            timeout: 5000

        test:
            adapter: sqlite3
            database: db/autolab_test
            pool: 5
            timeout: 5000

13. Granting permissions on the databases. Setting global sql mode is important to relax the rules of mysql when it comes to group by mode

        :::bash
        (access mysql using your root first to grant permissions)
        mysql> grant all privileges on autolab_development.* to '<username>'@localhost;
        mysql> grant all privileges on autolab_test.* to '<username>'@localhost;
        mysql> SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
        mysql> exit

14. Initializing Autolab Database

        :::bash
        cd Autolab
        bundle exec rails db:create
        bundle exec rails db:reset
        bundle exec rails db:migrate

15. Create initial root user, pass the `-d` flag for developmental deployments:

        :::bash
        # For production:
        ./bin/initialize_user.sh

        # For development:
        ./bin/initialize_user.sh -d

16. If you are just testing Autolab, you can populate the database with sample course & students

        :::bash
        cd Autolab
        bundle exec rails autolab:populate

17. Run Autolab!

        :::bash
        cd Autolab
        bundle exec rails s -p 3000 --binding=0.0.0.0

18. Visit localhost:3000 on your browser to view your local deployment of Autolab, and login with either the credentials of the root user you just created, or choose `Developer Login` with

        Email: "admin@foo.bar"

19. Install [Tango](/installation/tango), the backend autograding service. Information on linking Autolab to Tango can be found on this page
as well.

20. If you would like to deploy the server, you can try out <a href="https://www.phusionpassenger.com/library/walkthroughs/start/ruby.html" target="_blank">Phusion Passenger</a>.

21. If you would like to configure Github integration to allow students to submit via Github, please follow the [Github integration setup instructions](/installation/github_integration).

22. If you would like to configure LTI integration to link Autolab courses to LTI platforms, please follow the [LTI integration setup instructions](/installation/lti_integration).

23. Now you are all set to start using Autolab! Please fill out [this form](https://docs.google.com/forms/d/e/1FAIpQLSctfi3kwa03yuCuLgGF7qS_PItfk__1s80twhVDiKGQHvqUJg/viewform?usp=sf_link) to join our registry so that we can provide you with news about the latest features, bug-fixes, and security updates. For more info, visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab).