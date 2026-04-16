FactoryBot.define do
  factory :account do
    sequence(:email) { |n| "account#{n}@example.com" }
    password              { "Test1234!" }
    password_confirmation { "Test1234!" }
    account_type { :practitioner }
    active { true }

    trait :patient_type do
      account_type { :patient }
    end

    trait :locked do
      locked_at { 1.hour.ago }
      failed_attempts { 5 }
    end
  end
end
