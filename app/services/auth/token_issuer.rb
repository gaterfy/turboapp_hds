# frozen_string_literal: true

module Auth
  class TokenIssuer
    ACCESS_TOKEN_TTL = 1.hour
    ALGORITHM = "HS256"

    # Returns { access_token:, jti:, expires_at: }
    # Pass mfa_verified: true after a successful TOTP challenge.
    def self.issue_access_token(account, mfa_verified: false)
      jti = SecureRandom.uuid
      exp = ACCESS_TOKEN_TTL.from_now.to_i
      payload = {
        sub:          account.id.to_s,
        jti:          jti,
        exp:          exp,
        iat:          Time.current.to_i,
        account_type: account.account_type,
        mfa_verified: mfa_verified
      }
      token = JWT.encode(payload, signing_key(account), ALGORITHM)
      { access_token: token, jti: jti, expires_at: Time.at(exp) }
    end

    # Returns a new RefreshToken record.
    # `mfa_verified` is persisted on the refresh token so that subsequent
    # refreshes can re-issue access tokens with the same authentication level,
    # without forcing the user to re-perform MFA every time the access token rotates.
    def self.issue_refresh_token(account, request: nil, mfa_verified: false)
      account.refresh_tokens.create!(
        issued_ip:         request&.remote_ip,
        issued_user_agent: request&.user_agent,
        mfa_verified:      mfa_verified
      )
    end

    private_class_method def self.signing_key(account)
      "#{Rails.application.credentials.secret_key_base}:#{account.jti_secret}"
    end
  end
end
