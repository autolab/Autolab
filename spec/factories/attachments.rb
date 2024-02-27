FactoryBot.define do
  factory :attachment do
    course
    category_name { "General" }
    name { "hyperfastparrot.gif" }
    release_at { Time.current }
    file {
      Rack::Test::UploadedFile.new("spec/fixtures/attachments/hyperfastparrot.gif", "image/gif")
    }
  end
end
