This page provides instructions on installing Autolab for development on Mac OSX 10.11+. If you encounter any issue along the way, check out [Troubleshooting](/installation/troubleshoot).

Follow the step-by-step instructions below:

1. Install one of two database options

    -  <a href="https://www.tutorialspoint.com/sqlite/sqlite_installation.htm" target="_blank">SQLite</a> should **only** be used in development
    -  <a href="https://dev.mysql.com/doc/refman/8.0/en/macos-installation-pkg.html" target="_blank">MySQL</a> can be used in development or production

2. Install <a href="https://brew.sh/"> homebrew </a>

3. Install <a href="https://github.com/sstephenson/rbenv" target="_blank">rbenv</a> and ruby-build using homebrew:
       
        :::bash
        brew install rbenv ruby-build
    
    Restart your shell at this point in order to start using your newly installed rbenv.

4. Clone the Autolab repo into home directory and enter it:

        :::bash
        cd ~/
        git clone https://github.com/autolab/Autolab.git && cd Autolab

5. Install the correct version of ruby:

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

6. Install `bundler`:

        :::bash
        gem install bundler
        rbenv rehash

7. Install the required gems (run the following commands in the cloned Autolab repo):

        :::bash
        cd bin
        bundle install

    Refer to [Troubleshooting](/installation/troubleshoot) for issues installing gems.

8. Install the <a href="https://github.com/universal-ctags/homebrew-universal-ctags" target="_blank">universal-ctags</a> package:

        :::bash
        brew install --HEAD universal-ctags/universal-ctags/universal-ctags

    Afterward, run `which ctags` to ensure that the package lies on your `PATH` and can be found.

9. Initialize Autolab Configs

        :::bash
        cp config/database.yml.template config/database.yml
        cp config/school.yml.template config/school.yml
        cp config/autogradeConfig.rb.template config/autogradeConfig.rb

    - Edit `school.yml` with your school/organization specific names and emails.
    - Edit `database.yml` with the correct credentials for your chosen database. Refer to [Troubleshooting](/installation/troubleshoot) for any issues and suggested development [configurations](/installation/troubleshoot/#suggested-development-configuration-for-configdatabaseyml).

10. Create a .env file to store Autolab configuration constants. 

        :::bash
        cp .env.template .env

    If you have not installed Tango yet, you do not need to do anything else in this stage. If you have already installed Tango, you should make sure to fill in the `.env` file with values consistent with Tango's `config.py`

11. Initialize application secrets.

        :::bash
        ./bin/initialize_secrets.sh

12. Create and initialize the database tables:

        :::bash
        bundle exec rails db:create
        bundle exec rails db:migrate

    Do not forget to use `bundle exec` in front of every rake/rails command.

13. Create initial root user, pass the `-d` flag for developmental deployments:

        :::bash
        # For production:
        ./bin/initialize_user.sh

        # For development:
        ./bin/initialize_user.sh -d

14. Populate dummy data (for development only):

        :::bash
        bundle exec rails autolab:populate

15. Start the rails server:

        :::bash
        bundle exec rails s -p 3000

16. Go to localhost:3000 and login with either the credentials of the root user you just created, or choose `Developer Login` with:

        :::bash
        Email: "admin@foo.bar".

17. Install [Tango](/installation/tango), the backend autograding service. Information on linking Autolab to Tango can be found on this page
as well.

18. If you would like to configure Github integration to allow students to submit via Github, please follow the [Github integration setup instructions](/installation/github_integration).

19. If you would like to configure LTI integration to link Autolab courses to LTI platforms, please follow the [LTI integration setup instructions](/installation/lti_integration).

20. Now you are all set to start using Autolab! Please fill out [this form](https://docs.google.com/forms/d/e/1FAIpQLSctfi3kwa03yuCuLgGF7qS_PItfk__1s80twhVDiKGQHvqUJg/viewform?usp=sf_link) to join our registry so that we can provide you with news about the latest features, bug-fixes, and security updates. For more info, visit the [Guide for Instructors](/instructors) and [Guide for Lab Authors](/lab).