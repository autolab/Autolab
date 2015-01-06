FactoryGirl.define do
  factory :assessment do
    due_date { 2.weeks.from_now.to_s(:db) }
    submit_until { (2.weeks.from_now + 2.days).to_s(:db) }
    visible_at { 1.days.ago.to_s(:db) }
    start_date { visible_at }

    sequence(:name) { |n| "assessment_#{n}" }
    sequence(:display_name) { |n| "Assessment #{n}" }

    # We still want these so that assessments can have submissions
    # but they should always be mocked unless we're explicity
    # testing file system interaction.
    handin_filename "placeholder"
    handin_directory "placeholder"

    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.weeks.ago.to_s(:db) }
  end
end
