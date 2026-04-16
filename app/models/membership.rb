# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :account
  belongs_to :organization

  enum :role, { practitioner: 0, admin: 1, assistant: 2 }, validate: true

  validates :role, presence: true
  validates :account_id, uniqueness: { scope: :organization_id, message: "already has a membership in this organization" }

  scope :active, -> { where(active: true) }

  def admin?
    role == "admin"
  end

  def practitioner?
    role == "practitioner"
  end

  def assistant?
    role == "assistant"
  end
end
