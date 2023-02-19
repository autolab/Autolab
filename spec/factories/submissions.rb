FactoryBot.define do
  factory :submission do
    version { 0 }
    course_user_datum_id { 0 }
    assessment_id { 0 }
    filename { "hello.c" }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
    notes { "" }
    mime_type { "application/x-tgz" }
    special_type { 0 }
    submitted_by_id { 0 }
    autoresult { "" }
    detected_mime_type { "application/x-tgz" }
    submitter_ip { "123.456.789" }
    tweak_id { 0 }
    ignored { false }
    dave { "" }
    settings { "" }
    embedded_quiz_form_answer { "" }
    submitted_by_app_id { 0 }
    group_key { "" }
    jobid { 0 }
  end
end
