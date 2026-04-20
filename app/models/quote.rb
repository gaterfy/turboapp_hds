# frozen_string_literal: true

# Treatment quote.
#
# State machine:
#   draft → sent      (totals frozen, line items immutable)
#   sent  → signed    (patient has accepted)
#   sent  → rejected  (patient has refused)
#   draft | sent → expired
#
# Invariant: once sent, line items and amounts cannot change.
class Quote < ApplicationRecord
  include AASM

  MUTABLE_STATUSES = %w[draft].freeze

  belongs_to :patient_record
  belongs_to :practitioner
  belongs_to :organization

  has_many :line_items, class_name: "QuoteLineItem", dependent: :destroy

  validates :quote_number, presence: true, uniqueness: true
  validates :status, presence: true

  before_validation :generate_quote_number, on: :create

  scope :active,            -> { where.not(status: %w[rejected expired]) }
  scope :pending_signature, -> { where(status: "sent") }

  aasm column: :status, whiny_persistence: true do
    state :draft, initial: true
    state :sent
    state :signed
    state :rejected
    state :expired

    event :send_to_patient do
      transitions from: :draft, to: :sent
      after { freeze_totals! }
    end

    event :sign do
      transitions from: :sent, to: :signed
      after { update!(signed_at: Time.current) }
    end

    event :reject do
      transitions from: :sent, to: :rejected
      after { update!(rejected_at: Time.current) }
    end

    event :expire do
      transitions from: %i[draft sent], to: :expired
      after { update!(expired_at: Time.current) }
    end
  end

  def mutable?
    MUTABLE_STATUSES.include?(status)
  end

  def recalculate_totals!
    raise ActiveRecord::ReadOnlyRecord, "Cannot recalculate totals on a #{status} quote" unless mutable?

    assign_attributes(
      total_fees:               line_items.sum { |l| l.unit_fee * l.quantity },
      total_reimbursement_base: line_items.sum(&:reimbursement_base),
      total_patient_share:      line_items.sum(&:patient_share)
    )
    save!
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      patient_record_id: patient_record_id,
      practitioner_id: practitioner_id,
      quote_number: quote_number,
      status: status,
      valid_until: valid_until,
      total_fees: total_fees,
      total_reimbursement_base: total_reimbursement_base,
      total_patient_share: total_patient_share,
      notes: notes,
      signature_submission_id: signature_submission_id,
      sent_at: sent_at,
      signed_at: signed_at,
      rejected_at: rejected_at,
      expired_at: expired_at,
      treatment_plan_id: treatment_plan_id,
      line_items: line_items.order(:position).map(&:as_api_json),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Contrat JSON type turboapp `Devis#to_json_api` (routes /api/v1/devis).
  def to_logosw_json
    {
      id: id,
      dossier_patient_id: patient_record_id,
      practitioner_id: practitioner_id,
      plan_de_traitement_id: treatment_plan_id,
      devis_number: quote_number,
      status: status,
      sent_at: sent_at,
      signed_at: signed_at,
      rejected_at: rejected_at,
      expired_at: expired_at,
      valid_until: valid_until,
      total_honoraires: total_fees.to_f,
      total_base_remboursement: total_reimbursement_base.to_f,
      total_reste_a_charge: total_patient_share.to_f,
      docuseal_submission_id: signature_submission_id,
      notes: notes,
      lignes: line_items.order(:position).map(&:to_logosw_json),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def freeze_totals!
    reload
    update!(
      sent_at: Time.current,
      total_fees:               line_items.sum { |l| l.unit_fee * l.quantity },
      total_reimbursement_base: line_items.sum(&:reimbursement_base),
      total_patient_share:      line_items.sum(&:patient_share)
    )
  end

  def generate_quote_number
    return if quote_number.present?

    prefix = "QT-#{Time.current.strftime('%Y%m')}"
    seq = self.class.where("quote_number LIKE ?", "#{prefix}%").count + 1
    self.quote_number = "#{prefix}-#{seq.to_s.rjust(4, '0')}"
  end
end
