class Account < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :trackable,
         :validatable,
         :lockable

  enum :account_type, { practitioner: 0, patient: 1 }, validate: true

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :refresh_tokens, dependent: :destroy
  has_many :audit_logs

  validates :account_type, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  before_create :set_jti_secret

  # ─── MFA ──────────────────────────────────────────────────────────────────
  def setup_mfa!
    secret = ROTP::Base32.random
    update!(mfa_secret: secret, mfa_enabled: false)
    secret
  end

  def enable_mfa!(otp_code)
    return false unless mfa_secret.present?
    totp = ROTP::TOTP.new(mfa_secret, issuer: "TurboApp HDS")
    return false unless totp.verify(otp_code.to_s, drift_behind: 30, drift_ahead: 30)

    backup_codes = Array.new(8) { SecureRandom.hex(5) }
    update!(mfa_enabled: true, mfa_enabled_at: Time.current, mfa_backup_codes: backup_codes)
    backup_codes
  end

  def disable_mfa!
    update!(mfa_enabled: false, mfa_secret: nil, mfa_enabled_at: nil, mfa_backup_codes: [])
  end

  def verify_mfa!(code)
    return false unless mfa_enabled? && mfa_secret.present?

    if mfa_backup_codes.include?(code.to_s)
      codes = mfa_backup_codes - [code.to_s]
      update_column(:mfa_backup_codes, codes)
      return true
    end

    ROTP::TOTP.new(mfa_secret, issuer: "TurboApp HDS")
               .verify(code.to_s, drift_behind: 30, drift_ahead: 30)
               .present?
  end

  def totp_provisioning_uri(email = self.email)
    return nil unless mfa_secret.present?
    ROTP::TOTP.new(mfa_secret, issuer: "TurboApp HDS").provisioning_uri(email)
  end

  scope :active, -> { where(active: true) }

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  def membership_in(organization)
    memberships.active.find_by(organization: organization)
  end

  def rotate_jti_secret!
    update!(jti_secret: SecureRandom.uuid)
  end

  private

  def set_jti_secret
    self.jti_secret ||= SecureRandom.uuid
  end
end
