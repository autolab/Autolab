FactoryBot.define do
  factory :problem do
    sequence(:name) { |n| "problem_#{n}" }
    description { "This is a sample problem" }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
    max_score { 100 }
    optional { false }
    assessment_id { 0 }
  end
end
