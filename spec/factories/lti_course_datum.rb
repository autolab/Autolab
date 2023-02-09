FactoryBot.define do
  factory :lti_course_datum do
    context_id { "012345" }
    course_id { 0 }
    last_synced { 1.day.ago.to_s(:db) }
    membership_url { "https://example.org" }
    platform { "example.org" }
  end
end
