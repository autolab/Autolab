FactoryBot.define do
  factory :assessment do
    due_at { 2.weeks.from_now.to_s(:db) }
    end_at { (2.weeks.from_now + 2.days).to_s(:db) }
    start_at { 1.days.ago.to_s(:db) }
    grading_deadline { 5.weeks.from_now.to_s(:db) }

    sequence(:name) { |n| "assessment_#{n}" }
    sequence(:display_name) { |n| "Assessment #{n}" }
    # We still want these so that assessments can have submissions
    # but they should always be mocked unless we're explicity
    # testing file system interaction.
    handin_filename { |n| "handin_file_#{n}" }
    handin_directory { |n| "handin_directory_#{n}" }
    category_name { |n| "category_#{n}" }
    max_size {1_024_000}
    max_submissions { 10 }
    created_at { 2.weeks.ago.to_s(:db) }
    updated_at { 1.weeks.ago.to_s(:db) }
    course
  end
end
