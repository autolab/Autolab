FactoryBot.define do
  factory :course_user_datum do
    association :user, factory: :user
    course
    factory :student do
      lecture { "Auto-populated" }
      section { "B" }
      instructor { false }
      course_assistant { false }

      trait :nicknamed do
        sequence(:nickname) { |n| "user_#{n}" }
      end

      trait :dropped do
        dropped { true }
      end

      factory :nicknamed_student, traits: [:nicknamed]
      factory :dropped_student, traits: [:dropped]
    end

    factory :instructor do
      instructor { true }
    end

    factory :course_assistant do
      instructor { false }
      course_assistant { true }
    end
  end
end
