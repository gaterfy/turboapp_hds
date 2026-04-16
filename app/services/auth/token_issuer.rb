# frozen_string_literal: true

module Auth
  class TokenIssuer
    ACCESS_TOKEN_TTL = 1.hour
    ALGORITHM = "HS256"

    # Returns { access_token:, jti:, expires_at: }
    def self.issue_access_token(account)
      jti = SecureRandom.uuid
      exp = ACCESS_TOKEN_TTL.from_now.to_i
      payload = {
        sub: account.id.to_s,
        jti: jti,
        exp: exp,
        iat: Time.current.to_i,
        account_type: account.account_type
      }
      token = JWT.encode(payload, signing_key(account), ALGORITHM)
      { access_token: token, jti: jti, expires_at: Time.at(exp) }
    end

    # Returns a new RefreshToken record
    def self.issue_refresh_token(account, request: nil)
      account.refresh_tokens.create!(
        issued_ip: request&.remote_ip,
        issued_user_agent: request&.user_agent
      )
    end

    private_class_method def self.signing_key(account)
      "#{Rails.application.credentials.secret_key_base}:#{account.jti_secret}"
    end
  end
end
