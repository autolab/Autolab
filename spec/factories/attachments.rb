FactoryBot.define do
  factory :attachment do
    course
    assessment
    category_name { "General" }
    name { "attachment.txt" }
    release_at { Time.current }
    file { fixture_file_upload("attachments/attachment.txt", "text/plain") }
  end
end
