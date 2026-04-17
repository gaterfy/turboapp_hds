# frozen_string_literal: true

module Audit
  # Scrubs PII out of audit metadata before it is written to the database.
  #
  # HDS / GDPR minimization principle: audit logs are retained for years and
  # shipped to SIEM. They must not carry directly-identifying data beyond the
  # account_id / organization_id foreign keys already present on the row.
  #
  # Rules:
  #   - email-looking values are replaced by sha256(pepper + normalized_email)
  #     truncated to 16 chars. This lets ops correlate events involving the
  #     same address without exposing the address itself.
  #   - Other keys in an explicit blocklist are replaced by "[FILTERED]".
  #   - Everything else is kept as-is (action names, booleans, ids, durations).
  class MetadataScrubber
    EMAIL_REGEXP = URI::MailTo::EMAIL_REGEXP

    FILTERED_KEYS = %w[
      password passwd secret token access_token refresh_token
      assertion sso_assertion authorization otp otp_code
      mfa_secret mfa_backup_codes backup_codes private_key
      ssn insee rpps adeli iban cvv cvc siret
    ].freeze

    def self.call(metadata)
      return {} if metadata.nil?

      metadata.each_with_object({}) do |(k, v), acc|
        key = k.to_s
        acc[key] = scrub_value(key, v)
      end
    end

    def self.scrub_value(key, value)
      return "[FILTERED]" if FILTERED_KEYS.any? { |pattern| key.include?(pattern) }

      case value
      when Hash
        call(value)
      when Array
        value.map { |item| scrub_value(key, item) }
      when String
        value.match?(EMAIL_REGEXP) ? hash_email(value) : value
      else
        value
      end
    end
    private_class_method :scrub_value

    def self.hash_email(email)
      pepper = ENV["AUDIT_EMAIL_PEPPER"].to_s
      digest = Digest::SHA256.hexdigest("#{pepper}:#{email.downcase.strip}")
      "email_sha256:#{digest.first(16)}"
    end
    private_class_method :hash_email
  end
end
