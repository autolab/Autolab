#!/bin/sh
# Run this from Autolab root

if ! ls Gemfile > /dev/null 2>&1 ; then 
  echo "Please run this from Autolab root"
  exit 1
fi

SECRET_KEY_BASE=$(bundle exec rails secret)
LOCKBOX_MASTER_KEY=$(echo 'Lockbox.generate_key' | bundle exec rails c | grep "\".*\"" | tr -d "\"")
DEVISE_SECRET_KEY=$(bundle exec rake secret)

if ! perl -i -pe"s/<SECRET_KEY_BASE_REPLACE_ME>/${SECRET_KEY_BASE}/g" .env ; then
  echo "SECRET_KEY_BASE seems to have already been set"
fi

if ! perl -i -pe"s/<LOCKBOX_MASTER_KEY_REPLACE_ME>/${LOCKBOX_MASTER_KEY}/g" .env ; then
  echo "LOCKBOX_MASTER_KEY seems to have already been set"
fi

if ! perl -i -pe"s/<DEVISE_SECRET_KEY_REPLACE_ME>/${DEVISE_SECRET_KEY}/g" .env ; then
  echo "DEVISE_SECRET_KEY seems to have already been set"
fi

echo ".env file secrets have been initialized"
echo "If you want to use Github integration for submission via Git, please update .env with your Github application credentials"
