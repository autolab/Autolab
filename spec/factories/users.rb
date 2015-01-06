FactoryGirl.define do
  factory :user do
    first_name "Test"
    sequence (:last_name) { |n| "User #{n}" }
    sequence (:andrewID) { |n| "test#{n}" }
    nickname "Test User"
    sequence (:email) { |n| "test#{n}@andrew.cmu.edu" }
    confirmed_at Time.now

    factory :instructor do
      instructor true
      administrator true
      course_assistant false
    end
  end
end
