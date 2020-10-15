# Welcome to the Autolab Docs

Autolab is a course management platform that enables instructors to offer autograded programming assignments to their students. The two key ideas in Autolab are _autograding_ that is, programs evaluating other programs, and _scoreboards_ that display the latest autograded scores for each student. Autolab also provides gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

For information on how to use Autolab for your course see the [Guide for Instructors](/instructors). To learn how to write an autograded lab see the [Guide for Lab Authors](/lab). To get straight to an installation, go to [Getting Started](#getting-started)

## Demonstration Site
If you would like to check out Autolab prior to installation, go over to our <a href="http://autolab.ml" target="_blank">Demo Site</a>! Login through `Developer Login` with the email: `admin@foo.bar`. 

This is a demonstration website. It refreshes at 0,6,12,18 Hours (UTC) daily, and it is publicly accessible, so please only use it for your exploration. Do not use this site to store important information.

Try the following in order:

### Create a new course 
Click on `Manage Autolab` (top-right navigation bar) > `Create New Course`. Fill in the name and semester, and then create to see your course on the homepage.

(NOTE: the email doesn't need to be real here)

### Create an Autograded Lab Assessment. 
Go into the course you have just created, click on `Install Assessment`. You can install a simple autograded lab, called hello lab.
[Download hello.tar](https://github.com/autolab/Autolab/raw/master/examples/hello.tar) and install it using the `Import from Tarball` option. 

In the `hello` lab, students are asked to write a file called `hello.c`. The autograder checks that the submitted hello.c program compiles and runs with an exit status of zero. If so, the submission gets 100 points. Otherwise it gets 0 points. 

**Try submitting to the autograded hello lab**

1. Create and submit a `hello.c` file. 
       
        //hello.c
        #include <stdio.h>
        int main()
        {
                printf("Hello, World!");
                return 0;
        }

2. Refresh the submitted entries page to see the autograded score appear
3. Click on a sub score, in this case the `100.0` under the `Correctness` heading, to see the output from the autograder.

For more information on `hello` lab, or how to create your own lab, go to [Guide for Lab Authors](/lab)! 

### Create a PDF homework assessment
Autolab can also handle pdf submissions as well!

Click on `Install Assessment`, then on `Assessment Builder`. Name your assessment, and give it a category and click `Create Assessment`!. 

Because it defaults to accepting `.c` files, we would like to change it to `*.pdf`. Click on `Edit Assessment` > `Handin` and then change the `Handin filename` to `handin.pdf` instead of `handin.c` and save the changes

**Try submitting to the pdf homework asssessment.**

1. Submit a `.pdf` file.
2. Look at your submission using the magnifying glass icon

### Grading submissions
Click on `Grade Submissions`, and then the arrow button to open up student submissions. For details on the relevant features for an Instructor, go to [Guide for Instructor](/instructors)

## Getting Started

Autolab consists of two services: (1) the Ruby on Rails frontend, and (2) [Tango](/tango), the RESTful Python autograding server. Either service can run independently without the other. But in order to use all features of Autolab, we highly recommend installing both services.

Currently, we have support for installing Autolab on [Ubuntu 18.04+](#ubuntu-1804), and [Mac OSX](#mac-osx-1011).

### Mac OSX 10.11+

Follow the step-by-step instructions below:

1.  Install [rbenv](https://github.com/sstephenson/rbenv) (use the Basic GitHub Checkout method)

2.  Install [ruby-build](https://github.com/sstephenson/ruby-build) as an rbenv plugin:

        :::bash
        git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build

    Restart your shell at this point in order to start using your newly installed rbenv

3.  Clone the Autolab repo into home directory and enter it:

        :::bash
        cd ~/
        git clone https://github.com/autolab/Autolab.git && cd Autolab

4.  Install the correct version of ruby:

        :::bash
        rbenv install $(cat .ruby-version)

    At this point, confirm that `rbenv` is working (you might need to restart your shell):

        :::bash
        $ which ruby
        ~/.rbenv/shims/ruby

        $ which rake
        ~/.rbenv/shims/rake
    Note that Mac OSX comes with its own installation of ruby. You might need to switch your ruby from
    the system version to the rbenv installed version. One option is to add the following lines to ~/.bash_profile:
    
        :::bash
        export RBENV_ROOT=<rbenv folder path on your local machine>
        eval "$(rbenv init -)"

5.  Install `bundler`:

        :::bash
        gem install bundler
        rbenv rehash

6.  Install the required gems (run the following commands in the cloned Autolab repo):

        :::bash
        cd bin
        bundle install

    Refer to the [FAQ](#faq) for issues installing gems

7.  Install one of two database options

    -   [SQLite](https://www.tutorialspoint.com/sqlite/sqlite_installation.htm) should **only** be used in development
    -   [MySQL](https://dev.mysql.com/doc/refman/5.7/en/osx-installation-pkg.html) can be used in development or production

8.  Configure your database:

        :::bash
        cp config/database.yml.template config/database.yml

    Edit `database.yml` with the correct credentials for your chosen database. Refer to the [FAQ](#faq) for any issues.

9.  Configure school/organization specific information (new feature):

        :::bash
        cp config/school.yml.template config/school.yml

    Edit `school.yml` with your school/organization specific names and emails

10. Configure the Devise Auth System with a unique key (run these commands exactly - leave `<YOUR-SECRET-KEY>` as it is):

        :::bash
        cp config/initializers/devise.rb.template config/initializers/devise.rb
        sed -i "s/<YOUR-SECRET-KEY>/`bundle exec rake secret`/g" config/initializers/devise.rb

    Fill in `<YOUR_WEBSITE>` in the `config/initializers/devise.rb` file. To skip this step for now, fill with `foo.bar`.

11. Create and initialize the database tables:

        :::bash
        bundle exec rake db:create
        bundle exec rake db:migrate

    Do not forget to use `bundle exec` in front of every rake/rails command.

12. Populate dummy data (development only):

        :::bash
        bundle exec rake autolab:populate

13. Start the rails server:

        :::bash
        bundle exec rails s -p 3000

14. Go to localhost:3000 and login with `Developer Login`:

        :::bash
        Email: "admin@foo.bar".

15. Install [Tango](/tango), the backend autograding service.

16. Now you are all set to start using Autolab! Visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab) pages for more info.

### Ubuntu 18.04+ 

This set of instruction is meant to install of AutoLab v2.40 on Ubuntu 18.04 LTS.

1. Upgrade system packages and installing prerequisites

        :::bash
        sudo apt-get update
        sudo apt-get upgrade
        sudo apt-get install build-essential git libffi-dev zlib1g-dev autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev libncurses5-dev libgdbm5 libgdbm-dev libmysqlclient-dev libjansson-dev ctags

2. Cloning Autolab repo from Github to ~/Autolab

        :::bash
        cd ~/
        git clone https://github.com/autolab/Autolab.git
        cd Autolab

3. Setting up rbenv and ruby-build plugin

        :::bash
        cd ~/
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

5. Installing SQLite

        :::bash
        sudo apt-get install sqlite3 libsqlite3-dev

6. Installing MySQL. (If you would just like to test Autolab, then you can skip this step by using SQLite)
Following instructions from [How to Install MySQL on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-18-04).

        :::bash
        sudo apt install mysql-server
        sudo mysql_secure_installation

        > There will be a few questions asked during the MySQL setup.

        * Validate Password Plugin? N
        * Remove Annonymous Users? Y
        * Disallow Root Login Remotely? Y
        * Remove Test Database and Access to it? Y
        * Reload Privilege Tables Now? Y

7. (If you are using MySQL) Create a new user with access to `autolab_test` and `autolab_development` databases. Because a password rather than auth_socket is needed, we need to ensure that user uses `mysql_native_password`

        :::bash
        sudo mysql
        mysql> CREATE USER 'user1'@'localhost' IDENTIFIED WITH mysql_native_password BY '<password>';
        mysql> FLUSH PRIVILEGES;
        mysql> exit;

8. Installing Rails

        :::bash
        cd Autolab
        gem install bundler
        rbenv rehash
        bundle install

9. Initializing Autolab Configs

        :::bash
        cd Autolab
        cp config/database.yml.template config/database.yml
        cp config/school.yml.template config/school.yml
        cp config/initializers/devise.rb.template config/initializers/devise.rb
        sed -i "s/<YOUR-SECRET-KEY>/`bundle exec rake secret`/g" config/initializers/devise.rb
        cp config/autogradeConfig.rb.template config/autogradeConfig.rb

10. (Using MySQL) Editing Database YML.
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

11. (Using SQLite) Editing Database YML.
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

12. Granting permissions on the databases. Setting global sql mode is important to relax the rules of mysql when it comes to group by mode

        :::bash
        (access mysql using your root first to grant permissions)
        mysql> grant all privileges on autolab_development.* to '<username>'@localhost;
        mysql> grant all privileges on autolab_test.* to '<username>'@localhost;
        mysql> SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
        mysql> exit

12. Initializing Autolab Database

        :::bash
        cd Autolab
        bundle exec rake db:create
        bundle exec rake db:reset
        bundle exec rake db:migrate

13. Populating sample course & students

        :::bash
        cd Autolab
        bundle exec rake autolab:populate

14. Run Autolab!

        :::bash
        cd Autolab
        bundle exec rails s -p 3000 --binding=0.0.0.0

15. Visit localhost:3000 on your browser to view your local deployment of Autolab, and login with `Developer Login`

        Email: "admin@foo.bar"

16. Install [Tango](/tango), the backend autograding service.

17. If you would like to deploy the server, you can try out [Phusion Passenger](https://www.phusionpassenger.com/library/walkthroughs/start/ruby.html)

18. Now you are all set to start using Autolab! Visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab) pages for more info.

<!-- Removed pending docker fix
### Docker (Development) (rails-5-docker-dev)
This sets up a development setup of Autolab, Tango, and Redis locally with Docker Compose.


1. First ensure that Docker is installed

        :::bash
        docker --version

2. Cloning Autolab repo from Github to ~/Autolab, checkout to
   rails-5-docker-dev branch

        :::bash
        cd ~/
        git clone https://github.com/autolab/Autolab.git
        cd Autolab
        git checkout rails-5-docker-dev
        git pull

3. Start Docker Compose

        ::bash
        docker-compose up -d # detached mode

4. View your running containers

        ::bash
        docker ps
-->

## FAQ

This is a general list of questions that we get often. If you find a solution to an issue not mentioned here,
please contact us at <autolab-dev@andrew.cmu.edu>

#### Ubuntu Script Bugs

If you get the following error

```bash
Failed to fetch http://dl.google.com/linux/chrome/deb/dists/stable/Release
Unable to find expected entry 'main/binary-i386/Packages' in Release file (Wrong sources.list entry or malformed file)
```

then follow the solution in [this post](http://askubuntu.com/questions/743814/unable-to-find-expected-entry-main-binary-i386-packages-chrome).

#### Where do I find the MySQL username and password?
If this is your first time logging into MySQL, your username is 'root'. You may also need to set the root password:

Start the server:

```bash
sudo /usr/local/mysql/support-files/mysql.server start
```

Set the password:

```bash
mysqladmin -u root password "[New_Password]"
```

If you lost your root password, refer to the [MySQL wiki](http://dev.mysql.com/doc/refman/5.7/en/resetting-permissions.html)

#### Bundle Install Errors
This happens as gems get updated. These fixes are gem-specific, but two common ones are

`eventmachine`

```bash
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

`libv8`

```bash
bundle config build.libv8 --with-system-v8
```

Run `bundle install` again

If this does not work, another option would be

```bash
bundle update libv8
```

Because updating libv8 has dependency on other gems, it might fail due to a need to update other gems. Just do

```bash
bundle update <gem>
```

according to the error messages until all gems are up to date.

Run `bundle install` again

If neither of these works, try exploring [this StackOverflow link](http://stackoverflow.com/questions/23536893/therubyracer-gemextbuilderror-error-failed-to-build-gem-native-extension)

#### Can't connect to local MySQL server through socket
Make sure you've started the MySQL server and double-check the socket in `config/database.yml`

The default socket location is `/tmp/mysql.sock`.

#### I forgot my MySQL root password

You can reset it following the instructions on [this Stack Overflow post](http://stackoverflow.com/questions/6474775/setting-the-mysql-root-user-password-on-os-x)

If `mysql` complains that the password is expired, follow the instructions on the second answer on [this post](http://stackoverflow.com/questions/33326065/unable-to-access-mysql-after-it-automatically-generated-a-temporary-password)

#### MySQL Syntax Error

If you get the following error

```bash
Mysql2::Error: You have an error in your SQL syntax
```

this may be an issue with using an incompatible version of MySQL. Try switching to MySQL 5.7 if you are currently using a different version.
