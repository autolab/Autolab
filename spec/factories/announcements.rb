FactoryBot.define do
  factory :announcement do
    sequence(:title) { |n| "test_announcement_#{n}" }
    sequence(:description) { |n| "this is test_announcement_#{n}" }
    start_date { 2.weeks.ago.to_s(:db) }
    end_date { 1.week.from_now.to_s(:db) }
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.week.ago.to_s(:db) }
    course_user_datum_id
    course_id
    persistent { false }
    system { false }
  end
end
