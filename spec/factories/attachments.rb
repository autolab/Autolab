FactoryBot.define do
  factory :attachment do
    course_id { 1 }
    assessment_id { 1 }
    name { "attachment.txt" }
    release_at { Time.current }
    file { fixture_file_upload("attachments/attachment.txt", "text/plain") }
  end
end
