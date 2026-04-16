FactoryBot.define do
  factory :membership do
    account
    organization
    role { :practitioner }
    active { true }

    trait :admin do
      role { :admin }
    end

    trait :assistant do
      role { :assistant }
    end
  end
end
