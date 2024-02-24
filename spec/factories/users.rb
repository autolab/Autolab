FactoryBot.define do
  factory :user do
    first_name { "Test" }
    sequence(:last_name) { |n| "User #{n}" }
    sequence(:email) { |n| "test#{n}@andrew.cmu.edu" }
    password { "testPassword" }
    confirmed_at { Time.zone.now }
    administrator { false }
    trait :has_school_major_year do
      school { "Autopopulated University" }
      major  { "CS" }
      year   { "2090" }
    end
    factory :admin_user do
      administrator { true }
      first_name { "Admin" }
    end
    factory :instructor_user do
      first_name { "Instructor" }
    end
    factory :ca_user do
      first_name { "CA" }
    end
  end
end
