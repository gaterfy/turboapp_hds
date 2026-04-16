FactoryBot.define do
  factory :prescription do
    patient_record
    organization { patient_record.organization }
    practitioner
    prescription_date { Date.current }
    status { "draft" }

    trait :signed do
      status { "signed" }
      signed_at { 1.hour.ago }
    end
  end
end
