FactoryBot.define do
  factory :treatment_plan do
    patient_record
    organization { patient_record.organization }
    practitioner
    title         { "Full mouth rehabilitation" }
    description   { "Multi-step treatment plan" }
    status        { "proposed" }
    session_count { 4 }
    estimated_total { "1200.00" }

    trait :accepted do
      status      { "accepted" }
      accepted_at { 1.day.ago }
      accepted_total { "1200.00" }
    end

    trait :started do
      status     { "started" }
      accepted_at { 2.days.ago }
      accepted_total { "1200.00" }
      started_at { 1.day.ago }
    end

    trait :completed do
      status        { "completed" }
      accepted_at   { 3.days.ago }
      accepted_total { "1200.00" }
      started_at    { 2.days.ago }
      completed_at  { 1.day.ago }
    end
  end
end
