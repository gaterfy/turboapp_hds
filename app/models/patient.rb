# frozen_string_literal: true

# Administrative identity of the patient within an organization.
# Clinical data (history, allergies, dental chart) is carried by PatientRecord,
# which is the aggregate root of the clinical domain.
class Patient < ApplicationRecord
  STATUSES = %w[active inactive archived blocked].freeze

  belongs_to :organization
  belongs_to :account, optional: true

  has_one  :patient_record, dependent: :destroy
  has_many :appointments, dependent: :destroy

  validates :first_name, :last_name, :email, :birth_date, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :email, uniqueness: { scope: :organization_id }

  scope :active, -> { where(status: "active") }
  scope :search, ->(query) {
    where("first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def age
    return nil unless birth_date

    ((Time.zone.now - birth_date.to_time) / 1.year.seconds).floor
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
      mobile: mobile,
      birth_date: birth_date,
      age: age,
      gender: gender,
      address: address,
      city: city,
      postal_code: postal_code,
      country: country,
      insurance_provider: insurance_provider,
      insurance_number: insurance_number,
      status: status,
      emergency_contact: emergency_contact,
      emergency_phone: emergency_phone,
      notes: notes,
      patient_record_id: patient_record&.id,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
