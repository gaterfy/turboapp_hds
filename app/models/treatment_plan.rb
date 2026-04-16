# frozen_string_literal: true

# Clinical treatment plan: sequence of acts proposed to a patient.
#
# State machine:
#   proposed → accepted   (patient signs / practitioner validates)
#   accepted  → started   (first session begins)
#   started   → completed (all sessions done)
#   Any state → cancelled
#
# Invariant: once accepted, financial totals are frozen (accepted_total).
class TreatmentPlan < ApplicationRecord
  include AASM

  belongs_to :patient_record
  belongs_to :practitioner
  belongs_to :organization

  has_many :items, class_name: "TreatmentPlanItem", dependent: :destroy
  has_many :quotes, dependent: :nullify

  validates :title,  presence: true
  validates :status, presence: true

  scope :active_plans, -> { where(status: %w[proposed accepted started]) }

  aasm column: :status, whiny_persistence: true do
    state :proposed, initial: true
    state :accepted
    state :started
    state :completed
    state :cancelled

    event :accept do
      transitions from: :proposed, to: :accepted
      after do
        update!(
          accepted_at:    Time.current,
          accepted_total: estimated_total
        )
      end
    end

    event :start do
      transitions from: :accepted, to: :started
      after { update!(started_at: Time.current) }
    end

    event :complete do
      transitions from: :started, to: :completed
      after { update!(completed_at: Time.current) }
    end

    event :cancel do
      transitions from: %i[proposed accepted started], to: :cancelled
      after { update!(cancelled_at: Time.current) }
    end
  end

  def mutable?
    %w[proposed].include?(status)
  end

  def completion_percentage
    return 0 if items.empty?
    ((items.where(completed: true).count.to_f / items.count) * 100).round
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      patient_record_id: patient_record_id,
      practitioner_id: practitioner_id,
      title: title,
      description: description,
      status: status,
      session_count: session_count,
      estimated_total: estimated_total,
      accepted_total: accepted_total,
      completion_percentage: completion_percentage,
      accepted_at: accepted_at,
      started_at: started_at,
      completed_at: completed_at,
      cancelled_at: cancelled_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
