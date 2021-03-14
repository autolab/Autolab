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
        sed -i "s/<YOUR-SECRET-KEY>/`bundle exec rails secret`/g" config/initializers/devise.rb

    Fill in `<YOUR_WEBSITE>` in the `config/initializers/devise.rb` file. To skip this step for now, fill with `foo.bar`.

11. Create and initialize the database tables:

        :::bash
        bundle exec rails db:create
        bundle exec rails db:migrate

    Do not forget to use `bundle exec` in front of every rake/rails command.

12. Populate dummy data (development only):

        :::bash
        bundle exec rails autolab:populate

13. Start the rails server:

        :::bash
        bundle exec rails s -p 3000

14. Go to localhost:3000 and login with `Developer Login`:

        :::bash
        Email: "admin@foo.bar".

15. Install [Tango](/tango#installation), the backend autograding service.

16. Now you are all set to start using Autolab! Visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab) pages for more info.