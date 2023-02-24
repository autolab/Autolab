FactoryBot.define do
  factory :score do
    association :problem, factory: :problem
    sequence(:submission_id) { |n| }
    score { 0 }
    feedback { "" }
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.week.ago.to_s(:db) }
    grader_id { 1 }
    released { false }

    trait :released do
      release { true }
    end

    factory :released_score, traits: [:released]
  end
end
