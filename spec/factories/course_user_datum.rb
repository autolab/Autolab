FactoryBot.define do
  factory :course_user_datum do
    association :user, factory: :user
    course
  end
end
