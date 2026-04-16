# frozen_string_literal: true

module Auth
  class TokenVerifier
    ALGORITHM = "HS256"

    class Error < StandardError; end
    class ExpiredToken < Error; end
    class RevokedToken < Error; end
    class InvalidToken < Error; end

    # Returns decoded payload hash on success, raises on failure.
    def self.verify!(token)
      # Decode without verification first to get account_id and resolve signing key
      unverified = JWT.decode(token, nil, false).first
      account = Account.find_by(id: unverified["sub"])
      raise InvalidToken, "Unknown account" unless account
      raise InvalidToken, "Account is inactive" unless account.active?

      signing_key = "#{Rails.application.credentials.secret_key_base}:#{account.jti_secret}"
      payload = JWT.decode(token, signing_key, true, algorithms: [ ALGORITHM ]).first

      raise RevokedToken, "Token has been revoked" if JwtDenylist.revoked?(payload["jti"])

      payload
    rescue JWT::ExpiredSignature
      raise ExpiredToken, "Access token has expired"
    rescue JWT::DecodeError => e
      raise InvalidToken, e.message
    end
  end
end
