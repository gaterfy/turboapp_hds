# frozen_string_literal: true

class Practitioner < ApplicationRecord
  CLINICAL_ROLES = %w[dentist orthodontist surgeon assistant hygienist owner].freeze
  STATUSES       = %w[active on_leave inactive].freeze

  belongs_to :organization
  belongs_to :account

  has_many :patient_records, foreign_key: :primary_practitioner_id, dependent: :nullify
  has_many :appointments, dependent: :restrict_with_error

  validates :first_name, :last_name, :email, :specialization, :license_number, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :clinical_role, inclusion: { in: CLINICAL_ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :license_number, uniqueness: { scope: :organization_id }

  scope :active, -> { where(status: "active") }

  def full_name
    "#{first_name} #{last_name}"
  end

  def as_api_json
    {
      id: id,
      organization_id: organization_id,
      first_name: first_name,
      last_name: last_name,
      full_name: full_name,
      email: email,
      phone: phone,
      specialization: specialization,
      license_number: license_number,
      clinical_role: clinical_role,
      status: status,
      working_hours: working_hours,
      skills: skills,
      rating: rating,
      total_reviews: total_reviews,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
