FactoryBot.define do
  factory :assessment_user_datum do
    course_user_datum_id
    assessment_id
    latest_submission_id
    group_id
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.week.ago.to_s(:db) }
    # for groups, not really sure how this works
    trait :confirmed do
      confirmed { AssessmentUserDatum::CONFIRMED }
    end
  end
end
