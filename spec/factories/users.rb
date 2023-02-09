FactoryBot.define do
  factory :user do
    first_name { "Test" }
    sequence(:last_name) { |n| "User #{n}" }
    sequence(:email) { |n| "test#{n}@andrew.cmu.edu" }
    password { "testPassword" }

    confirmed_at { Time.zone.now }
  end
end
