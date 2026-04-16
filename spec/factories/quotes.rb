FactoryBot.define do
  factory :quote do
    patient_record
    organization { patient_record.organization }
    practitioner
    status { "draft" }

    trait :sent do
      status { "sent" }
      sent_at { 1.hour.ago }
    end

    trait :signed do
      status { "signed" }
      sent_at { 2.hours.ago }
      signed_at { 1.hour.ago }
    end
  end
end
