# Dockerfile from
#
#     https://intercityup.com/blog/how-i-build-a-docker-image-for-my-rails-app.html
#
# See more documentation at the passenger-docker GitHub repo:
#
#     https://github.com/phusion/passenger-docker
#
#
FROM phusion/passenger-ruby26

MAINTAINER Autolab Development Team "autolab-dev@andrew.cmu.edu"

# Change to your time zone here
RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

# Install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  sqlite3 \
  tzdata

# Install gems
WORKDIR /tmp
ADD Gemfile /tmp/
ADD Gemfile.lock /tmp/

RUN bundle install

# Set correct environment variables.
ENV HOME /root
ENV DEPLOY_METHOD docker

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down
# Remove the default site
RUN rm /etc/nginx/sites-enabled/default
# Add the nginx info
ADD docker/nginx.conf /etc/nginx/sites-enabled/webapp.conf

# Prepare folders
RUN mkdir /home/app/webapp

# Add the rails app
ADD . /home/app/webapp

# Move the database configuration into place
ADD config/database.docker.yml /home/app/webapp/config/database.yml

# Move other configs
ADD docker/school.yml /home/app/webapp/config/school.yml
ADD docker/production.rb /home/app/webapp/config/environments/production.rb
ADD docker/devise.rb /home/app/webapp/config/initializers/devise.rb
ADD docker/autogradeConfig.rb /home/app/webapp/config/autogradeConfig.rb
ADD docker/initialize_user.sh /home/app/webapp/docker/initialize_user.sh

# Create the log files
RUN mkdir -p /home/app/webapp/log && \
  touch /home/app/webapp/log/production.log && \
  chown -R app:app /home/app/webapp/log && \
  chmod 0664 /home/app/webapp/log/production.log

# precompile the Rails assets
WORKDIR /home/app/webapp
RUN RAILS_ENV=production bundle exec rake assets:precompile

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
