# frozen_string_literal: true

FactoryBot.define do
  factory :penalty do
    value { 15 }
    kind { "percent" }
  end
end
