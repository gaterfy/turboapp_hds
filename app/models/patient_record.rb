# frozen_string_literal: true

# Aggregate root of the clinical domain.
# Every clinical document (consultation, quote, prescription) attaches here.
# One record per patient per organization – enforced at DB level.
class PatientRecord < ApplicationRecord
  STATUSES = %w[active archived transferred].freeze

  belongs_to :patient
  belongs_to :organization
  belongs_to :primary_practitioner, class_name: "Practitioner", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :patient_id, uniqueness: { scope: :organization_id,
                                       message: "already has a record in this organization" }

  scope :active, -> { where(status: "active") }

  def archive!(reason: nil)
    update!(status: "archived", closed_at: Time.current)
  end

  def transfer!
    update!(status: "transferred", closed_at: Time.current)
  end

  def active?
    status == "active"
  end

  def as_api_json
    {
      id: id,
      patient_id: patient_id,
      organization_id: organization_id,
      primary_practitioner_id: primary_practitioner_id,
      status: status,
      allergies: allergies,
      chronic_diseases: chronic_diseases,
      medications: medications,
      blood_type: blood_type,
      medical_notes: medical_notes,
      dental_chart: dental_chart,
      ai_health_score: ai_health_score,
      opened_at: opened_at,
      closed_at: closed_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
