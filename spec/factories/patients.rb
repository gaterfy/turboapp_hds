FactoryBot.define do
  factory :patient do
    organization
    account { nil }
    sequence(:first_name) { |n| "Patient#{n}" }
    last_name  { "Test" }
    sequence(:email) { |n| "patient#{n}@example.com" }
    birth_date { 30.years.ago.to_date }
    status     { "active" }

    trait :with_account do
      account { create(:account, account_type: :patient) }
    end
  end
end
