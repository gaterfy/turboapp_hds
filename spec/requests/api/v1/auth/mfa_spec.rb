# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MFA endpoints", type: :request do
  let(:account) { create(:account) }
  let(:headers) do
    token = ::Auth::TokenIssuer.issue_access_token(account)[:access_token]
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  describe "POST /api/v1/auth/mfa/setup" do
    it "returns a TOTP secret and provisioning URI" do
      post "/api/v1/auth/mfa/setup", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "secret")).to be_present
      expect(json_body.dig("data", "provisioning_uri")).to include("otpauth://totp/")
    end

    it "rejects if MFA is already enabled" do
      account.update_columns(mfa_enabled: true, mfa_secret: ROTP::Base32.random)

      post "/api/v1/auth/mfa/setup", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/auth/mfa/confirm" do
    before { account.setup_mfa! }

    it "enables MFA with a valid OTP and returns backup codes" do
      valid_otp = ROTP::TOTP.new(account.mfa_secret).now

      post "/api/v1/auth/mfa/confirm",
           params: { otp_code: valid_otp }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      backup_codes = json_body.dig("data", "backup_codes")
      expect(backup_codes).to be_an(Array)
      expect(backup_codes.size).to eq(8)
      expect(account.reload.mfa_enabled?).to be true
    end

    it "rejects with an invalid OTP" do
      post "/api/v1/auth/mfa/confirm",
           params: { otp_code: "000000" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.reload.mfa_enabled?).to be false
    end
  end

  describe "POST /api/v1/auth/mfa/verify" do
    before do
      account.setup_mfa!
      account.enable_mfa!(ROTP::TOTP.new(account.mfa_secret).now)
    end

    it "returns an mfa_verified access token with a valid OTP" do
      valid_otp = ROTP::TOTP.new(account.mfa_secret).now

      post "/api/v1/auth/mfa/verify",
           params: { otp_code: valid_otp }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "mfa_verified")).to be true
      expect(json_body.dig("data", "access_token")).to be_present
    end

    it "rejects with invalid OTP" do
      post "/api/v1/auth/mfa/verify",
           params: { otp_code: "000000" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/mfa/disable" do
    before do
      account.setup_mfa!
      account.enable_mfa!(ROTP::TOTP.new(account.mfa_secret).now)
    end

    it "disables MFA with correct OTP" do
      valid_otp = ROTP::TOTP.new(account.mfa_secret).now

      delete "/api/v1/auth/mfa/disable",
             params: { otp_code: valid_otp }.to_json,
             headers: headers

      expect(response).to have_http_status(:no_content)
      expect(account.reload.mfa_enabled?).to be false
    end
  end
end
