#!/usr/bin/env bash

# This is the legacy One-Click install script
# It probably doesn't work anymore, but is left here as reference

#####################################
## Initialization & Helper Functions
#####################################
shopt -s extglob
set -e
set -o errtrace
set -o errexit

# Email and signup link are Base64-coded to prevent scraping
OUR_EMAIL=`echo -n 'YXV0b2xhYi1kZXZAYW5kcmV3LmNtdS5lZHU=' | base64 -d`
LIST_SIGNUP=`echo -n 'aHR0cDovL2VlcHVybC5jb20vYlRUT2lU' | base64 -d`
SCRIPT_PATH="${BASH_SOURCE[0]}";

AUTOLAB_PATH="${HOME}/Autolab";

# Colorful output
_red=`tput setaf 1`
_green=`tput setaf 2`
_orange=`tput setaf 3`
_blue=`tput setaf 4`
_purple=`tput setaf 5`
_cyan=`tput setaf 6`
_white=`tput setaf 6`
_reset=`tput sgr0`

# Log file
LOG_FILE=`mktemp`

# Global helpers
log()  { printf "${_green}%b${_reset}\n" "$*"; printf "\n%b\n" "$*" >> $LOG_FILE; }
logstdout() { printf "${_green}%b${_reset}\n" "$*" 2>&1 ; }
warn() { printf "${_orange}%b${_reset}\n" "$*"; printf "%b\n" "$*" >> $LOG_FILE; }
fail() { printf "\n${_red}ERROR: $*${_reset}\n"; printf "\nERROR: $*\n" >> $LOG_FILE; }

# Confirm prompt defaulting to 'no'
confirm () {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [y/N] " response
    case $response in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# Confirm prompt defaulting to 'yes'
confirm_yes() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [Y/n] " response
    case $response in
        [nN][oO]|[nN])
            false
            ;;
        *)
            true
            ;;
    esac

}

# Traps for completion and error
cleanup() {
    ERR_CODE=$?
    log "\nThank you for trying out Autolab! For questions and comments, email us at $OUR_EMAIL.\n"
    [ -z "$PSWD_REMINDER" ] || logstdout "As a final reminder, your MySQL root password is: $PSWD_REMINDER."
    unset MYSQL_ROOT_PSWD
    unset PSWD_REMINDER
    exit ${ERR_CODE:-0}
}

err_report() {
    ERR_CODE=$?

    # Ignore Ctrl-C interrupts
    if [ $ERR_CODE == 130 ];
    then
        return
    fi

    # Handle normal errors
    ERR_LINE=`sed -n "$1p" < $SCRIPT_PATH | sed -e 's/^[ \t]*//'`
    warn "Failed command: $ERR_LINE"
    fail "Line $1 of script has return value $ERR_CODE. The log file is saved at $LOG_FILE."
    exit $ERR_CODE
}

trap 'cleanup' EXIT
trap 'err_report $LINENO' ERR

############################################
## Setup Task Specifications
############################################

## Section One: Pre-requisites
environment_setup() {
    clear
    log "Upgrading system packages and installing prerequisites..."
    sudo apt-get -y -qq update
    sudo apt-get -y -qq upgrade
    sudo apt-get -y -qq install build-essential git libffi-dev zlib1g-dev autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev libncurses5-dev libgdbm3 libgdbm-dev libmysqlclient-dev libjansson-dev ctags

    log "Cloning Autolab repo from Github to ~/Autolab..."
    if [[ -d "$AUTOLAB_PATH" ]]; then
        confirm "Directoy ~/Autolab already exists... Do you want to overwrite it?" && rm -rf ~/Autolab
        fi
    git clone https://github.com/autolab/Autolab.git ~/Autolab
}

## Section Two: Set up Rbenv and ruby-build plugin
rbenv_setup() {
    log "Cloning Rbenv repo from Github to ~/.rbenv..."
    if [[ -d "$HOME/.rbenv" ]]; then
        confirm "Directoy ~/.rbenv already exists... Do you want to overwrite it?" && rm -rf ~/.rbenv
        fi
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv

    log "Setting up Rbenv..."
    # For future use
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    # For current run
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"

    log "Cloning ruby-build repo from Github to ~/.rbenv/plugins/ruby-build..."
    if [[ -d "$HOME/.rbenv/plugins/ruby-build" ]]; then
        confirm "Directoy ~/.rbenv/plugins/ruby-build already exists... Do you want to overwrite it?" && rm -rf ~/.rbenv/plugins/ruby-build
        fi
    git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
}

## Section Three: Install Ruby
ruby_setup() {
    log "Installing Ruby `cat $AUTOLAB_PATH/.ruby-version` for Autolab..."
    rbenv install `cat $AUTOLAB_PATH/.ruby-version`
    #source ~/.bashrc
}

## Section Four: MySQL & SQLite installation
db_setup() {
    log "Installing SQLite with apt-get..."
    sudo apt-get -y -qq install sqlite3 libsqlite3-dev

    log "Installing MySQL Server..."
    # Check if MySQL exists
    if hash mysql 2>/dev/null; then
        if confirm_yes "\nIt appears that MySQL Server already exists on your system. Want to skip to configuration?"; then
            read -s -p "Root password for MySQL Server: " MYSQL_ROOT_PSWD
            printf "\n"
            read -n1 -rsp $'Please make sure MySQL server is running, and press any key to continue...\n'
            return
        else
            log "Attempting to install MySQL Server on top of existing one..."
        fi
    fi

    # Install and configure MySQL
    MYSQL_ROOT_PSWD=`date +%s | sha256sum | base64 | head -c 32`
    PSWD_REMINDER=$MYSQL_ROOT_PSWD
    echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PSWD" | sudo debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PSWD" | sudo debconf-set-selections
    sudo apt-get -y -qq install mysql-server

    printf "${_orange}Your randomly-generated root password for MySQL server is: %s. Please keep the password in a safe place for future use.${_reset}\n" $PSWD_REMINDER
    read -n1 -rsp $'Press any key to continue the installation...\n'
}

## Section Five: Install Rails
rails_setup() {
    log "Installing necessary gems for Autolab..."
    cd $AUTOLAB_PATH
    gem install bundler
    rbenv rehash
    bundle install
}

## Section Six: Initialize Autolab configs
autolab_setup() {
    cd $AUTOLAB_PATH

    log "Initializing Autolab configurations..."
    cp $AUTOLAB_PATH/config/database.yml.template $AUTOLAB_PATH/config/database.yml
    sed -i "s/<username>/$USER/g" $AUTOLAB_PATH/config/database.yml

    cp $AUTOLAB_PATH/config/school.yml.template $AUTOLAB_PATH/config/school.yml

    cp $AUTOLAB_PATH/config/initializers/devise.rb.template $AUTOLAB_PATH/config/initializers/devise.rb
    sed -i "s/<YOUR-SECRET-KEY>/`bundle exec rake secret`/g" $AUTOLAB_PATH/config/initializers/devise.rb

    cp $AUTOLAB_PATH/config/autogradeConfig.rb.template $AUTOLAB_PATH/config/autogradeConfig.rb

    log "Granting MySQL database permissions..."
    mysql -uroot -p$MYSQL_ROOT_PSWD -e "GRANT ALL PRIVILEGES ON ""$USER""_autolab_development.* TO '$USER'@'%' IDENTIFIED BY '<password>'"
    mysql -uroot -p$MYSQL_ROOT_PSWD -e "GRANT ALL PRIVILEGES ON ""$USER""_autolab_test.* TO '$USER'@'%' IDENTIFIED BY '<password>'"
    warn "Your MySQL server password for \`$USER\` appears in ~/Autolab/config/database.yml in clear text. Make sure to change the default password and protect the file!"
}

## Section Seven: Autolab database initialization
autolab_init() {
    log "Populating tables in Autolab database..."

    cd $AUTOLAB_PATH
    bundle exec rake db:create
    bundle exec rake db:reset
    bundle exec rake db:migrate
}

## Section Eight: Populate samples courses & students
autolab_populate() {
    if confirm "Generate sample users and courses? (Recommended for a quick demo, not for serious users)"; then
        cd $AUTOLAB_PATH
        bundle exec rake autolab:populate
    fi
}

## Section Nine: Congrats!
congrats() {
    log "
Autolab installation is now complete. When you start a new login-shell, you may run the following command to start up Autolab server at Port 3000:
                         ${_orange}cd ~/Autolab && bundle exec rails s -p 3000 --binding=0.0.0.0${_reset}

Top things to do after installation:

- Try out Tango (https://github.com/autolab/Tango), the back-end service for Autolab, and fill in relevant parameters in ./config/autogradeConfig.rb
- Sign up for our mailing list to learn about new features and bug fixes: $LIST_SIGNUP
- Change MySQL root password (the password we generated is not strong enough for serious use.)
- Change MySQL password for \`$USER\`, and update it in ./config/database.yml (default password is '<password>')
- Contact us if you have any questions!"
}

#########################################################
## Main Entry Point
##
## If you know what you are doing, feel free to comment
## out certain steps to skip them.
#########################################################

environment_setup
rbenv_setup
ruby_setup
db_setup
rails_setup
autolab_setup
autolab_init
autolab_populate
congrats
