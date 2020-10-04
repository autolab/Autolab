#!/bin/bash

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
    read -sp "Password (again): " $password2_confirm
done
  echo
  read -p 'First Name: ' first_name
  read -p 'Last Name: ' last_name

  bundle exec rake admin:create_root_user[$email,"$password","$first_name","$last_name"]
}

add_a_user
