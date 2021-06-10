#!/bin/bash

env='production'

add_a_user()
{
  echo "############## Initialize a new root user ##############"
  read -p 'User Email: ' email
  read -sp 'Password: ' password
  echo
  read -sp 'Confirm Password: ' password2_confirm
  while [ "$password" != "$password2_confirm" ];
do
    echo
    echo "Inconsistent password, please try again"
    read -sp "Password: " password
    echo
    read -sp "Password (again): " password2_confirm
done
  echo
  read -p 'First Name: ' first_name
  read -p 'Last Name: ' last_name

  RAILS_ENV=$1 bundle exec rails admin:create_root_user[$email,"$password","$first_name","$last_name"]
}

while getopts 'd' flag; do
    case "${flag}" in
    d) env="development" ;;
  esac
done

add_a_user $env
