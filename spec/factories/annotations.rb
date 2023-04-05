FactoryBot.define do
  factory :annotation do
    submission_id { 0 }
    filename { "hello.c" }
    position { 0 }
    line { 0 }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
    submitted_by { 0 }
    comment { "this is a comment" }
    value { 0 }
    problem_id { 0 }
    coordinate { nil }
    shared_comment { false }
    global_comment { false }
  end
end
