FROM phusion/passenger-ruby26:1.0.13

# Change to your time zone here
RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

# Install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  sqlite3 \
  tzdata  \
  shared-mime-info

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down
# Remove the default site
RUN rm /etc/nginx/sites-enabled/default

# Install gems
WORKDIR /tmp
ADD Gemfile .
ADD Gemfile.lock .

RUN chown app:app Gemfile Gemfile.lock

# Prepare folders
USER app
RUN bundle install

RUN mkdir /home/app/webapp
WORKDIR /home/app/webapp

# Add the rails app
ADD . /home/app/webapp

USER root

# Create the log files
RUN mkdir -p /home/app/webapp/log && \
  touch /home/app/webapp/log/production.log && \
  chmod 0664 /home/app/webapp/log/production.log && \
  chown -R app:app .

USER root
RUN chown -R app:app .

WORKDIR /home/app/webapp

# Clean up APT when done.
USER root
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
