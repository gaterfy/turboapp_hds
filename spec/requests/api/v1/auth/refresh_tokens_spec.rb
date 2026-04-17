# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/refresh", type: :request do
  let(:account) { create(:account) }
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  def post_refresh(token_value)
    post "/api/v1/auth/refresh",
         params: { refresh_token: token_value }.to_json,
         headers: headers
  end

  context "with a valid, usable refresh token" do
    let!(:refresh_token) { ::Auth::TokenIssuer.issue_refresh_token(account, request: nil) }

    it "returns a new token pair" do
      post_refresh(refresh_token.token)

      expect(response).to have_http_status(:created)
      body = json_body

      expect(body.dig("data", "access_token")).to be_present
      expect(body.dig("data", "refresh_token")).to be_present
      expect(body.dig("data", "refresh_token")).not_to eq(refresh_token.token)
    end

    it "rotates the refresh token (revokes the old one)" do
      post_refresh(refresh_token.token)

      expect(refresh_token.reload.revoked?).to be true
    end

    it "the new access token grants access to protected endpoints" do
      org = create(:organization)
      create(:membership, account: account, organization: org)

      # Simulate a practitioner who has already passed MFA when the original
      # pair was emitted: the refresh token carries mfa_verified: true and must
      # propagate it to the newly-rotated access token.
      refresh_token.update!(mfa_verified: true)

      post_refresh(refresh_token.token)

      new_token = json_body.dig("data", "access_token")

      get "/api/v1/profile",
          headers: {
            "Authorization"     => "Bearer #{new_token}",
            "X-Organization-Id" => org.id.to_s
          }

      expect(response).to have_http_status(:ok)
    end

    it "preserves mfa_verified across rotations" do
      refresh_token.update!(mfa_verified: true)

      post_refresh(refresh_token.token)
      new_access = json_body.dig("data", "access_token")

      payload = ::Auth::TokenVerifier.verify!(new_access)
      expect(payload["mfa_verified"]).to eq(true)
    end

    it "does not upgrade mfa_verified on rotation if the original was false" do
      post_refresh(refresh_token.token)
      new_access = json_body.dig("data", "access_token")

      payload = ::Auth::TokenVerifier.verify!(new_access)
      expect(payload["mfa_verified"]).to eq(false)
    end
  end

  context "with a missing refresh_token param" do
    it "returns 400" do
      post "/api/v1/auth/refresh", headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  context "with an invalid token string" do
    it "returns 401" do
      post_refresh("not-a-real-token")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with an expired refresh token" do
    let!(:expired_token) do
      token = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)
      token.update!(expires_at: 1.day.ago)
      token
    end

    it "returns 401" do
      post_refresh(expired_token.token)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_token")
    end
  end

  context "with a revoked refresh token" do
    let!(:revoked_token) do
      token = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)
      token.revoke!(reason: "test")
      token
    end

    it "returns 401" do
      post_refresh(revoked_token.token)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with an inactive account" do
    let!(:refresh_token) { ::Auth::TokenIssuer.issue_refresh_token(account, request: nil) }
    before { account.update!(active: false) }

    it "returns 403" do
      post_refresh(refresh_token.token)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
