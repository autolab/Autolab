FactoryBot.define do
  factory :autograder do
    autograde_timeout { 180 }
    autograde_image { "autograding_image" }
    release_score { true }
    instance_type { "t3.micro" }
    use_access_key { false }
    association :assessment, factory: :assessment
  end
end
