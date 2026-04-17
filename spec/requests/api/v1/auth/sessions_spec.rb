# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/login & DELETE /api/v1/auth/logout", type: :request do
  let(:org)        { create(:organization) }
  let(:account)    { create(:account, email: "doc@example.com", password: "TestPass1234!", password_confirmation: "TestPass1234!") }
  let(:headers)    { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  # -------------------------------------------------------------------
  # Login
  # -------------------------------------------------------------------
  describe "POST /api/v1/auth/login" do
    context "with valid credentials" do
      it "returns a token pair and account info" do
        post "/api/v1/auth/login",
             params: { email: account.email, password: "TestPass1234!" }.to_json,
             headers: headers

        expect(response).to have_http_status(:created)
        body = json_body

        expect(body.dig("data", "access_token")).to be_present
        expect(body.dig("data", "refresh_token")).to be_present
        expect(body.dig("data", "account", "email")).to eq(account.email)
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/auth/login",
               params: { email: account.email, password: "TestPass1234!" }.to_json,
               headers: headers
        }.to change(AuditLog, :count).by(1)

        expect(AuditLog.last.action).to eq("login_success")
      end
    end

    context "with wrong password" do
      it "returns 401 invalid_credentials" do
        post "/api/v1/auth/login",
             params: { email: account.email, password: "wrong" }.to_json,
             headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(json_body.dig("error", "code")).to eq("invalid_credentials")
      end

      it "increments failed_attempts on the account" do
        expect {
          post "/api/v1/auth/login",
               params: { email: account.email, password: "wrong" }.to_json,
               headers: headers
        }.to change { account.reload.failed_attempts }.by(1)
      end
    end

    context "with unknown email" do
      it "returns 401" do
        post "/api/v1/auth/login",
             params: { email: "nobody@example.com", password: "TestPass1234!" }.to_json,
             headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an inactive account" do
      before { account.update!(active: false) }

      it "returns 403 account_inactive" do
        post "/api/v1/auth/login",
             params: { email: account.email, password: "TestPass1234!" }.to_json,
             headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(json_body.dig("error", "code")).to eq("account_inactive")
      end
    end

    context "with a locked account" do
      before { account.update_columns(locked_at: 5.minutes.ago) }

      it "returns 403 account_locked" do
        post "/api/v1/auth/login",
             params: { email: account.email, password: "TestPass1234!" }.to_json,
             headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(json_body.dig("error", "code")).to eq("account_locked")
      end
    end
  end

  # -------------------------------------------------------------------
  # Logout
  # -------------------------------------------------------------------
  describe "DELETE /api/v1/auth/logout" do
    let(:token_data) { ::Auth::TokenIssuer.issue_access_token(account) }
    let(:auth_headers) { headers.merge("Authorization" => "Bearer #{token_data[:access_token]}") }

    it "revokes the access token and returns 204" do
      delete "/api/v1/auth/logout", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(JwtDenylist.find_by(jti: token_data[:jti])).to be_present
    end

    it "revokes all active refresh tokens" do
      rt = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)

      delete "/api/v1/auth/logout", headers: auth_headers

      expect(rt.reload.revoked?).to be true
    end

    it "creates an audit log entry" do
      expect {
        delete "/api/v1/auth/logout", headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("logout")
    end

    it "rejects request without Authorization header" do
      delete "/api/v1/auth/logout", headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an already-revoked token" do
      delete "/api/v1/auth/logout", headers: auth_headers   # first logout
      delete "/api/v1/auth/logout", headers: auth_headers   # second attempt

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # -------------------------------------------------------------------
  # Protected endpoint – sanity checks
  # -------------------------------------------------------------------
  describe "accessing a protected endpoint" do
    it "returns 401 without Authorization header" do
      get "/api/v1/profile",
          headers: { "X-Organization-Id" => org.id.to_s }.merge(headers)

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 400 without X-Organization-Id header" do
      token = ::Auth::TokenIssuer.issue_access_token(account, mfa_verified: true)[:access_token]

      get "/api/v1/profile",
          headers: headers.merge("Authorization" => "Bearer #{token}")

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 403 when account has no membership in the given org" do
      other_org = create(:organization)
      token = ::Auth::TokenIssuer.issue_access_token(account, mfa_verified: true)[:access_token]

      get "/api/v1/profile",
          headers: headers.merge(
            "Authorization" => "Bearer #{token}",
            "X-Organization-Id" => other_org.id.to_s
          )

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 mfa_required when practitioner token has no mfa_verified claim" do
      org = create(:organization)
      create(:membership, account: account, organization: org)
      token = ::Auth::TokenIssuer.issue_access_token(account, mfa_verified: false)[:access_token]

      get "/api/v1/profile",
          headers: headers.merge(
            "Authorization" => "Bearer #{token}",
            "X-Organization-Id" => org.id.to_s
          )

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("mfa_required")
    end
  end
end
