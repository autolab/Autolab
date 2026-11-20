FactoryBot.define do
  factory :score do
    association :problem, factory: :problem
    association :submission, factory: :submission
    association :grader, factory: :course_user_datum
    score { 0 }
    feedback { "" }
    created_at { 2.weeks.ago.to_fs(:db) }
    updated_at { 1.week.ago.to_fs(:db) }
    released { false }
    trait :released do
      release { true }
    end

    factory :released_score, traits: [:released]
  end
end
