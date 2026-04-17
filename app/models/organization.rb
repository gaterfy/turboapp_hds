# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :memberships,   dependent: :destroy
  has_many :accounts,      through: :memberships
  has_many :audit_logs

  # Clinical domain
  has_many :practitioners,   dependent: :restrict_with_error
  has_many :patients,        dependent: :restrict_with_error
  has_many :patient_records, dependent: :restrict_with_error
  has_many :appointments,    dependent: :restrict_with_error
  has_many :consultations,    dependent: :restrict_with_error
  has_many :quotes,           dependent: :restrict_with_error
  has_many :prescriptions,    dependent: :restrict_with_error
  has_many :treatment_plans,  dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, digits and hyphens" }
  validates :turboapp_merchant_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end
end
