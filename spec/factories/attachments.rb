FactoryBot.define do
  factory :attachment do
    association :course
    name { "attachment.txt" }
    released { true }
    file { Rack::Test::UploadedFile.new("spec/files/test_attachment.txt", "text/plain") }
  end
end
