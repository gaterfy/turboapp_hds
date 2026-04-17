# frozen_string_literal: true

# Fail fast if any critical secret is missing in production.
# Avoids discovering at the first real request that a secret is unset.
if Rails.env.production?
  required = %w[
    SSO_ASSERTION_SECRET
    ALLOWED_ORIGINS
    APP_HOST
    AUDIT_EMAIL_PEPPER
  ]

  missing = required.select { |key| ENV[key].to_s.strip.blank? }

  if missing.any?
    raise "Missing required environment variables for production: #{missing.join(', ')}"
  end

  # Minimum entropy on SSO secret (256 bits = 64 hex chars).
  secret = ENV["SSO_ASSERTION_SECRET"].to_s
  if secret.length < 64
    raise "SSO_ASSERTION_SECRET must be at least 64 characters (256 bits of entropy)"
  end
end
