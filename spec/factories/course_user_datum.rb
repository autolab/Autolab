FactoryBot.define do
  factory :course_user_datum do
    association :user, factory: :user
    course
    factory :student do
      lecture { "Auto-populated" }
      section { "B" }
      instructor { false }
      course_assistant { false }
    end
  end
end
