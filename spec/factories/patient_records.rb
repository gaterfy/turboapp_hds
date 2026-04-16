FactoryBot.define do
  factory :patient_record do
    patient
    organization { patient.organization }
    status { "active" }
    opened_at { Time.current }
  end
end
