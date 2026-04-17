# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::TokenVerifier do
  let(:account) { create(:account) }

  describe "successful verification" do
    it "returns the decoded payload for a valid access token" do
      data = ::Auth::TokenIssuer.issue_access_token(account)
      payload = described_class.verify!(data[:access_token])

      expect(payload["sub"]).to eq(account.id.to_s)
      expect(payload["jti"]).to eq(data[:jti])
    end
  end

  # ---------------------------------------------------------------------------
  # Anti-enumeration: all invalid-token paths surface the SAME public message.
  # This prevents an attacker from distinguishing "unknown sub" from
  # "inactive account" from "bad signature" from "malformed JWT".
  # ---------------------------------------------------------------------------
  describe "anti-enumeration" do
    it "uses the same message when the sub does not exist" do
      bogus_payload = { sub: "99999999", jti: "x", exp: 1.hour.from_now.to_i }
      token = JWT.encode(bogus_payload, "whatever", "HS256")

      expect { described_class.verify!(token) }
        .to raise_error(Auth::TokenVerifier::InvalidToken, described_class::GENERIC_MESSAGE)
    end

    it "uses the same message when the account is inactive" do
      inactive = create(:account, active: false)
      token = JWT.encode({ sub: inactive.id.to_s, jti: "x", exp: 1.hour.from_now.to_i },
                         "whatever", "HS256")

      expect { described_class.verify!(token) }
        .to raise_error(Auth::TokenVerifier::InvalidToken, described_class::GENERIC_MESSAGE)
    end

    it "uses the same message when the signature is forged" do
      forged_key = "attacker-supplied-#{account.jti_secret}-wrong"
      token = JWT.encode(
        { sub: account.id.to_s, jti: SecureRandom.uuid, exp: 1.hour.from_now.to_i },
        forged_key, "HS256"
      )

      expect { described_class.verify!(token) }
        .to raise_error(Auth::TokenVerifier::InvalidToken, described_class::GENERIC_MESSAGE)
    end

    it "uses the same message on a completely malformed token" do
      expect { described_class.verify!("not-a-jwt") }
        .to raise_error(Auth::TokenVerifier::InvalidToken, described_class::GENERIC_MESSAGE)
    end
  end

  describe "specific error classes" do
    it "raises ExpiredToken on expired JWT" do
      signing_key = "#{Rails.application.credentials.secret_key_base}:#{account.jti_secret}"
      token = JWT.encode(
        { sub: account.id.to_s, jti: SecureRandom.uuid, exp: 1.minute.ago.to_i },
        signing_key, "HS256"
      )

      expect { described_class.verify!(token) }
        .to raise_error(Auth::TokenVerifier::ExpiredToken, described_class::GENERIC_MESSAGE)
    end

    it "raises RevokedToken when jti is in denylist" do
      data = ::Auth::TokenIssuer.issue_access_token(account)
      JwtDenylist.revoke!(jti: data[:jti], exp: 1.hour.from_now.to_i)

      expect { described_class.verify!(data[:access_token]) }
        .to raise_error(Auth::TokenVerifier::RevokedToken, described_class::GENERIC_MESSAGE)
    end
  end
end
