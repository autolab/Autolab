FactoryBot.define do
  factory :attachment do
    course_id { 1 }
    assessment_id { 1 }
    association :course
    name { "attachment.txt" }
    released { true }
    file { Rack::Test::UploadedFile.new("spec/fixtures/attachments/attachment.txt", "text/plain") }
  end
end
