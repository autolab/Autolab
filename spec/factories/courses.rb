FactoryBot.define do
  factory :course do
    sequence(:name) { |n| "test_course_#{n}" }
    sequence(:display_name) { |n| "Test Course #{n}" }
    semester { "t01" }
    late_slack { 3600 }
    grace_days { 4 }
    association :late_penalty, factory: :penalty
    version_threshold { 5 }
    association :version_penalty, factory: :penalty
    start_date { 1.day.ago.to_s(:db) }
    end_date { 100.days.from_now.to_s(:db) }
    disabled { false }
    association :lti_course_datum, factory: :lti_course_datum

    trait :with_attachment do
      after(:create) do |course|
        create(:attachment, course:)
      end
    end

    factory :course_with_attachment, traits: [:with_attachment]
  end
end
