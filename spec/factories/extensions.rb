FactoryBot.define do
  factory :extension do
    days { 1 }
    course_user_datum_id { 0 }
    assessment_id { 0 }
    trait :infinite_extension do
      infinite { true }
    end
  end
end
