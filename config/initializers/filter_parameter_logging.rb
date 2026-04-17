# Be sure to restart your server when you modify this file.
#
# HDS / PII-aware parameter filtering.
# Any request/log entry containing one of these keys is replaced with
# "[FILTERED]" in production logs. Partial matches work (e.g. "passw"
# matches "password_confirmation").
#
# Keep this list conservative: once a secret ends up in a log file it can
# propagate to backups, SIEM, etc.
Rails.application.config.filter_parameters += [
  # Classic auth
  :passw, :secret, :token, :_key, :crypt, :salt, :pepper,
  :reset_password_token, :unlock_token, :encrypted_password,

  # Session tokens
  :authorization, :access_token, :refresh_token, :jti, :jti_secret,

  # SSO cross-app
  :assertion, :sso_assertion,

  # MFA / TOTP
  :otp, :otp_code, :mfa_secret, :mfa_backup_codes, :backup_codes, :totp,

  # Certificates / keys
  :certificate, :private_key, :public_key, :signature,

  # PII / clinical (logs should never carry these)
  :email, :ssn, :insee, :rpps, :adeli,
  :cvv, :cvc, :iban, :bic, :siret
]
