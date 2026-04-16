# frozen_string_literal: true

class RefreshToken < ApplicationRecord
  EXPIRY_DURATION = 30.days

  belongs_to :account

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  before_validation :set_token_and_expiry, on: :create

  def revoke!(reason: "logout")
    update!(revoked_at: Time.current, revoked_reason: reason)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def usable?
    !revoked? && !expired?
  end

  private

  def set_token_and_expiry
    self.token ||= SecureRandom.hex(64)
    self.expires_at ||= EXPIRY_DURATION.from_now
  end
end
