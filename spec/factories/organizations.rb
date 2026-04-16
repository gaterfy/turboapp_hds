FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Cabinet #{n}" }
    slug { nil } # auto-generated from name
    active { true }
  end
end
