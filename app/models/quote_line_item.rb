# frozen_string_literal: true

# One procedure line on a Quote.
# Immutable once the parent Quote transitions out of :draft.
class QuoteLineItem < ApplicationRecord
  belongs_to :quote

  validates :label,    presence: true
  validates :unit_fee, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  before_create :assert_quote_is_mutable
  before_update :assert_quote_is_mutable
  before_destroy :assert_quote_is_mutable

  def as_api_json
    {
      id: id,
      quote_id: quote_id,
      procedure_code: procedure_code,
      label: label,
      tooth_location: tooth_location,
      quantity: quantity,
      position: position,
      unit_fee: unit_fee,
      reimbursement_base: reimbursement_base,
      reimbursement_rate: reimbursement_rate,
      reimbursement_amount: reimbursement_amount,
      patient_share: patient_share,
      overage: overage,
      line_total: (unit_fee || 0) * (quantity || 1)
    }
  end

  # Contrat JSON type turboapp `LigneDevis#to_json_api` (routes /api/v1/devis).
  def to_logosw_json
    {
      id: id,
      devis_id: quote_id,
      acte_ccam_id: nil,
      code_ccam: procedure_code,
      libelle: label,
      localisation: tooth_location,
      honoraires: (unit_fee.to_d * quantity).to_f,
      base_remboursement: reimbursement_base.to_f,
      taux_remboursement: reimbursement_rate.to_f,
      montant_rembourse: reimbursement_amount.to_f,
      reste_a_charge: patient_share.to_f,
      depassement: overage.to_f,
      quantite: quantity,
      position: position
    }
  end

  private

  def assert_quote_is_mutable
    unless quote.mutable?
      throw :abort
      # Raise after throw so the message is accessible if needed
      raise ActiveRecord::ReadOnlyRecord,
            "Cannot modify line items of a #{quote.status} quote"
    end
  end
end
