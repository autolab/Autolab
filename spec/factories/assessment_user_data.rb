FactoryBot.define do
  factory :assessment_user_datum do
    course_user_datum_id { 0 }
    assessment_id { 0 }
    latest_submission_id { 0 }
    group_id { 0 }
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.week.ago.to_s(:db) }
    # for groups, not really sure how this works
    trait :confirmed do
      confirmed { AssessmentUserDatum::CONFIRMED }
    end
  end
end
