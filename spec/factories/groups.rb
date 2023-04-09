FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "test_group_#{n}" }
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.week.ago.to_s(:db) }
  end
end
