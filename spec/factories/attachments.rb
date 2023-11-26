FactoryBot.define do
  factory :attachment do
    course_id { 1 }
    assessment_id { 1 }
    association :course
    name { "hyperfastparrot.gif" }
    released { true }
    file { Rack::Test::UploadedFile.new("spec/fixtures/attachments/hyperfastparrot.gif", "image/gif") }
  end
end
