FactoryBot.define do
  factory :github_integration do
    oauth_state { "MyString" }
    access_token { "MyString" }
    user { nil }
  end
end
