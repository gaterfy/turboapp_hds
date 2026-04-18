# frozen_string_literal: true

require "openssl"

class RefreshToken < ApplicationRecord
  EXPIRY_DURATION = 30.days

  belongs_to :account

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Jeton opaque transmis une seule fois au client (non persiste en base).
  attr_reader :issued_raw_token

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  before_validation :assign_digest_and_expiry, on: :create

  # Compatibilite avec les controleurs qui lisent `.token` juste apres emission.
  def token
    issued_raw_token
  end

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

  def self.find_by_raw_token(raw)
    return nil if raw.blank?

    find_by(token_digest: digest_for(raw.to_s.strip))
  end

  def self.digest_for(raw)
    OpenSSL::HMAC.hexdigest("SHA256", refresh_token_pepper, raw.to_s)
  end

  def self.refresh_token_pepper
    ENV.fetch("REFRESH_TOKEN_PEPPER") do
      Rails.application.credentials.secret_key_base
    end
  end
  private_class_method :refresh_token_pepper

  private

  def assign_digest_and_expiry
    raw = SecureRandom.hex(64)
    @issued_raw_token = raw
    self.token_digest = self.class.digest_for(raw)
    self.expires_at ||= EXPIRY_DURATION.from_now
  end
end
