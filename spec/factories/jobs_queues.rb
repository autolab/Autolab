FactoryBot.define do
  factory :jobs_queue do
    running_jobs { "MyText" }
    waiting_jobs { "MyText" }
  end
end
