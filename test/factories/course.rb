require "factory_girl"

FactoryGirl.define do
  factory :course do
    sequence(:name) { |n| "test_course_#{n}" }
    semester "t01"
    late_slack 3600
    grace_days 4
    late_penalty -0.15
    sequence(:display_name) { |n| "Test Course #{n}" }
    start_date { 1.days.ago.to_s(:db) }
    end_date { 100.days.from_now.to_s(:db) }
    disabled false
  end
end
