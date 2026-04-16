# frozen_string_literal: true

# One medication line on a Prescription.
# Immutable once the parent Prescription is signed.
class PrescriptionLineItem < ApplicationRecord
  belongs_to :prescription

  validates :medication, :dosage, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  before_create  :assert_prescription_is_mutable
  before_update  :assert_prescription_is_mutable
  before_destroy :assert_prescription_is_mutable

  def as_api_json
    {
      id: id,
      prescription_id: prescription_id,
      medication: medication,
      dosage: dosage,
      duration: duration,
      quantity: quantity,
      renewable: renewable,
      position: position,
      notes: notes
    }
  end

  private

  def assert_prescription_is_mutable
    unless prescription.mutable?
      throw :abort
    end
  end
end
