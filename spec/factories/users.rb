FactoryGirl.define do
  factory :user do
    sequence(:email){|n| "user#{n}@foo.bar" }
    password        "AutolabProject"
    sequence(:first_name){|n| "#{n}" }
    last_name       "User"
    confirmed_at    Time.now
  end
end
