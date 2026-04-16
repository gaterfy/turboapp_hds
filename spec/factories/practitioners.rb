FactoryBot.define do
  factory :practitioner do
    organization
    account
    sequence(:first_name) { |n| "Marie#{n}" }
    last_name     { "Dupont" }
    sequence(:email) { |n| "practitioner#{n}@example.com" }
    specialization { "Dentisterie générale" }
    sequence(:license_number) { |n| "LIC-#{n.to_s.rjust(6, '0')}" }
    clinical_role { "dentist" }
    status        { "active" }
  end
end
