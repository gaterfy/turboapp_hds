# frozen_string_literal: true

module Auth
  class TokenVerifier
    ALGORITHM = "HS256"
    GENERIC_MESSAGE = "Invalid or expired token"

    class Error        < StandardError; end
    class ExpiredToken < Error; end
    class RevokedToken < Error; end
    class InvalidToken < Error; end

    # Returns the decoded payload hash on success, raises on failure.
    #
    # Anti-enumeration: all InvalidToken failures raise with the same
    # public-facing message, whether the `sub` is unknown, inactive, or
    # the signature is wrong. The detailed reason is still logged internally
    # for ops/debugging via Rails.logger.debug.
    def self.verify!(token)
      unverified = JWT.decode(token, nil, false).first
      account    = Account.find_by(id: unverified["sub"])

      raise_invalid!("sub not found")    unless account
      raise_invalid!("account inactive") unless account.active?

      signing_key = "#{Rails.application.credentials.secret_key_base}:#{account.jti_secret}"
      payload     = JWT.decode(token, signing_key, true, algorithms: [ ALGORITHM ]).first

      if JwtDenylist.revoked?(payload["jti"])
        raise RevokedToken, GENERIC_MESSAGE
      end

      payload
    rescue JWT::ExpiredSignature
      raise ExpiredToken, GENERIC_MESSAGE
    rescue JWT::DecodeError => e
      log_debug("JWT decode error: #{e.message}")
      raise InvalidToken, GENERIC_MESSAGE
    end

    # Internal failure path: logs the real reason (debug only) and raises
    # the uniform public error.
    def self.raise_invalid!(reason)
      log_debug("token rejected: #{reason}")
      raise InvalidToken, GENERIC_MESSAGE
    end
    private_class_method :raise_invalid!

    def self.log_debug(msg)
      Rails.logger.debug("[TokenVerifier] #{msg}")
    end
    private_class_method :log_debug
  end
end
