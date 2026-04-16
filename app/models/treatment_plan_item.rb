# frozen_string_literal: true

# Individual act within a TreatmentPlan.
# Immutable once the parent plan is no longer :proposed.
class TreatmentPlanItem < ApplicationRecord
  belongs_to :treatment_plan

  validates :label,    presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_fee, numericality: { greater_than_or_equal_to: 0 }

  before_create :assert_plan_is_mutable
  before_update :assert_plan_is_mutable
  before_destroy :assert_plan_is_mutable

  default_scope { order(:position) }

  def subtotal
    quantity * unit_fee
  end

  def as_api_json
    {
      id: id,
      treatment_plan_id: treatment_plan_id,
      procedure_code: procedure_code,
      label: label,
      tooth_ref: tooth_ref,
      quantity: quantity,
      unit_fee: unit_fee,
      subtotal: subtotal,
      position: position,
      notes: notes,
      completed: completed,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def assert_plan_is_mutable
    unless treatment_plan.mutable?
      errors.add(:base, "Treatment plan items cannot be changed once the plan is #{treatment_plan.status}")
      throw :abort
    end
  end
end
