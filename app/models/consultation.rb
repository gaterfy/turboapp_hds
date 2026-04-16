# frozen_string_literal: true

# Clinical encounter attached to a PatientRecord.
#
# State machine:
#   in_progress → completed  (clinical content is sealed, snapshot taken)
#   completed   → locked     (permanent – no further edits by anyone)
#
# Invariant: once completed or locked, clinical fields cannot be modified.
class Consultation < ApplicationRecord
  include AASM

  EDITABLE_STATUSES = %w[in_progress].freeze
  LOCKED_STATUSES   = %w[completed locked].freeze

  belongs_to :patient_record
  belongs_to :practitioner
  belongs_to :appointment, optional: true
  belongs_to :organization

  has_many :prescriptions, dependent: :restrict_with_error

  validates :consultation_date, presence: true
  validates :status, presence: true
  validate  :prevent_clinical_edit_when_locked, on: :update

  scope :recent,     -> { order(consultation_date: :desc) }
  scope :for_period, ->(from, to) { where(consultation_date: from..to) }

  aasm column: :status, whiny_persistence: true do
    state :in_progress, initial: true
    state :completed
    state :locked

    event :complete do
      transitions from: :in_progress, to: :completed
      after do |chart_snapshot: nil|
        update!(
          completed_at: Time.current,
          dental_chart_snapshot: chart_snapshot || dental_chart_snapshot
        )
      end
    end

    # Named `seal` to avoid conflict with ActiveRecord's built-in `lock!` method. sure
    event :seal do
      transitions from: :completed, to: :locked
      after { update!(locked_at: Time.current) }
    end
  end

  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  def locked?
    status == "locked"
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      patient_record_id: patient_record_id,
      practitioner_id: practitioner_id,
      appointment_id: appointment_id,
      status: status,
      consultation_date: consultation_date,
      duration_minutes: duration_minutes,
      chief_complaint: chief_complaint,
      observations: observations,
      diagnosis: diagnosis,
      teeth_concerned: teeth_concerned,
      procedures_performed: procedures_performed,
      dental_chart_snapshot: dental_chart_snapshot,
      notes: notes,
      completed_at: completed_at,
      locked_at: locked_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  CLINICAL_FIELDS = %w[
    chief_complaint observations diagnosis teeth_concerned
    procedures_performed dental_chart_snapshot notes duration_minutes
  ].freeze

  def prevent_clinical_edit_when_locked
    return if editable?

    changed_clinical = (changes.keys & CLINICAL_FIELDS)
    return if changed_clinical.empty?

    errors.add(:base, "Cannot modify clinical content of a #{status} consultation (changed: #{changed_clinical.join(', ')})")
  end
end
