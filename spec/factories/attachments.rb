FactoryBot.define do
  factory :attachment do
    association :course
    name { "attachment.txt" }
    released { true }
    file { Rack::Test::UploadedFile.new("spec/fixtures/attachments/attachment.txt", "text/plain") }
  end
end
