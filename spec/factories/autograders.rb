FactoryBot.define do
  factory :autograder do
    autograde_timeout { 180 }
    autograde_image { "autograding_image" }
    release_score { true }
    association :assessment, factory: :assessment
  end
end
