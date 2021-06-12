This page provides instructions on installing Autolab for development on Mac OSX 10.11+. If you encounter any issue along the way, check out [Troubleshooting](/installation/troubleshoot).

Follow the step-by-step instructions below:

1.  Install <a href="https://github.com/sstephenson/rbenv" target="_blank">rbenv</a> (use the Basic GitHub Checkout method)

2.  Install <a href="https://github.com/sstephenson/ruby-build" target="_blank">ruby-build</a> as an rbenv plugin:

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

    Refer to [Troubleshooting](/installation/troubleshoot) for issues installing gems

7.  Install one of two database options

    -   <a href="https://www.tutorialspoint.com/sqlite/sqlite_installation.htm" target="_blank">SQLite</a> should **only** be used in development
    -   <a href="https://dev.mysql.com/doc/refman/5.7/en/osx-installation-pkg.html" target="_blank">MySQL</a> can be used in development or production

8.  Configure your database:

        :::bash
        cp config/database.yml.template config/database.yml

    Edit `database.yml` with the correct credentials for your chosen database. Refer to [Troubleshooting](/installation/troubleshoot) for any issues.

9.  Configure school/organization specific information (new feature):

        :::bash
        cp config/school.yml.template config/school.yml

    Edit `school.yml` with your school/organization specific names and emails

10. Configure the Devise Auth System with a unique key (run these commands exactly - leave `<YOUR-SECRET-KEY>` as it is):

        :::bash
        cp config/initializers/devise.rb.template config/initializers/devise.rb
        sed -i "s/<YOUR-SECRET-KEY>/`bundle exec rails secret`/g" config/initializers/devise.rb

    Fill in `<YOUR_WEBSITE>` in the `config/initializers/devise.rb` file. To skip this step for now, fill with `foo.bar`.

11. Create and initialize the database tables:

        :::bash
        bundle exec rails db:create
        bundle exec rails db:migrate

    Do not forget to use `bundle exec` in front of every rake/rails command.

12. Create initial root user, pass the `-d` flag for developmental deployments:

        :::bash
        # For production:
        ./bin/initialize_user.sh

        # For development:
        ./bin/initialize_user.sh -d

13. Populate dummy data (for development only):

        :::bash
        bundle exec rails autolab:populate

14. Start the rails server:

        :::bash
        bundle exec rails s -p 3000

15. Go to localhost:3000 and login with either the credentials of the root user you just created, or choose `Developer Login` with:

        :::bash
        Email: "admin@foo.bar".

16. Install [Tango](/installation/tango), the backend autograding service.

17. Now you are all set to start using Autolab! Visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab) pages for more info.