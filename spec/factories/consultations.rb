FactoryBot.define do
  factory :consultation do
    patient_record
    organization { patient_record.organization }
    practitioner
    consultation_date { Time.current }
    status { "in_progress" }

    trait :completed do
      status { "completed" }
      completed_at { 1.hour.ago }
      dental_chart_snapshot { { "snapshot" => true } }
    end

    trait :locked do
      status { "locked" }
      completed_at { 2.hours.ago }
      locked_at { 1.hour.ago }
    end
  end
end
