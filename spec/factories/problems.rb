FactoryBot.define do
  factory :problem do
    name { "Problem 1" }
    description { "This is a sample problem" }
    assessment_id { 0 }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
    max_score { 100 }
    optional { false }
  end
end
