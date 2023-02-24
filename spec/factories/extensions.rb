FactoryBot.define do
  factory :extension do
    course_user_datum_id
    assessment_id
    days { 1 }
    trait :infinite_extension do
      infinite { true }
    end
  end
end
