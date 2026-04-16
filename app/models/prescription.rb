# frozen_string_literal: true

# Medical prescription.
#
# State machine:
#   draft → signed    (content frozen, only practitioner can sign)
#   signed → delivered
#   draft | signed → cancelled
#
# Invariant: once signed, medication lines cannot be modified.
class Prescription < ApplicationRecord
  include AASM

  MUTABLE_STATUSES = %w[draft].freeze

  belongs_to :patient_record
  belongs_to :practitioner
  belongs_to :consultation, optional: true
  belongs_to :organization

  has_many :line_items, class_name: "PrescriptionLineItem", dependent: :destroy

  validates :prescription_number, presence: true, uniqueness: true
  validates :prescription_date, presence: true
  validates :status, presence: true

  before_validation :generate_prescription_number, on: :create

  scope :active, -> { where.not(status: "cancelled") }

  aasm column: :status, whiny_persistence: true do
    state :draft, initial: true
    state :signed
    state :delivered
    state :cancelled

    event :sign do
      transitions from: :draft, to: :signed
      after { update!(signed_at: Time.current) }
    end

    event :deliver do
      transitions from: :signed, to: :delivered
      after { update!(delivered_at: Time.current) }
    end

    event :cancel do
      transitions from: %i[draft signed], to: :cancelled
      after { update!(cancelled_at: Time.current) }
    end
  end

  def mutable?
    MUTABLE_STATUSES.include?(status)
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      patient_record_id: patient_record_id,
      practitioner_id: practitioner_id,
      consultation_id: consultation_id,
      prescription_number: prescription_number,
      prescription_date: prescription_date,
      status: status,
      notes: notes,
      signature_submission_id: signature_submission_id,
      signed_at: signed_at,
      delivered_at: delivered_at,
      cancelled_at: cancelled_at,
      line_items: line_items.order(:position).map(&:as_api_json),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def generate_prescription_number
    return if prescription_number.present?

    prefix = "RX-#{Time.current.strftime('%Y%m')}"
    seq = self.class.where("prescription_number LIKE ?", "#{prefix}%").count + 1
    self.prescription_number = "#{prefix}-#{seq.to_s.rjust(4, '0')}"
  end
end
