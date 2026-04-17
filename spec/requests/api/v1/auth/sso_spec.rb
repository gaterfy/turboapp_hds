# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/sso/exchange", type: :request do
  let(:sso_secret) { "a" * 64 }
  let(:email)      { "dr.martin@example.com" }
  let(:headers)    { { "Content-Type" => "application/json", "Accept" => "application/json" } }

  before { allow(ENV).to receive(:[]).and_call_original }
  before { allow(ENV).to receive(:[]).with("SSO_ASSERTION_SECRET").and_return(sso_secret) }

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_payload(overrides = {})
    {
      iss:                "turboapp",
      aud:                "turboapp_hds",
      sub:                email,
      merchant_id:        SecureRandom.uuid,
      organization_name:  "Cabinet Martin",
      name:               "Dr. Martin",
      role:               "practitioner",
      exp:                60.seconds.from_now.to_i,
      iat:                Time.current.to_i,
      jti:                SecureRandom.uuid
    }.merge(overrides)
  end

  def encode(payload, secret: sso_secret, algorithm: "HS256")
    JWT.encode(payload, secret, algorithm)
  end

  def post_exchange(assertion)
    post "/api/v1/auth/sso/exchange",
         params: { assertion: assertion }.to_json,
         headers: headers
  end

  # ---------------------------------------------------------------------------
  # Happy path
  # ---------------------------------------------------------------------------
  describe "with a valid assertion" do
    context "when the account does not exist" do
      it "provisions a new practitioner Account and returns tokens" do
        payload   = valid_payload
        assertion = encode(payload)

        expect { post_exchange(assertion) }.to change(Account, :count).by(1)
          .and change(Organization, :count).by(1)
          .and change(Membership, :count).by(1)
          .and change(Practitioner, :count).by(1)

        expect(response).to have_http_status(:created)
        body = json_body["data"]

        expect(body["access_token"]).to be_present
        expect(body["refresh_token"]).to be_present
        expect(body.dig("account", "email")).to eq(email)
        expect(body.dig("account", "account_type")).to eq("practitioner")

        created = Account.find(body.dig("account", "id"))
        expect(created.account_type).to eq("practitioner")
        expect(created.active).to be(true)

        org = Organization.find_by!(turboapp_merchant_id: payload[:merchant_id])
        expect(org.name).to eq("Cabinet Martin")
        expect(created.memberships.active.find_by(organization: org)).to be_present
      end

      it "consumes the jti (stored in denylist)" do
        payload   = valid_payload
        assertion = encode(payload)

        expect { post_exchange(assertion) }.to change(SsoAssertionDenylist, :count).by(1)
        expect(SsoAssertionDenylist.consumed?(payload[:jti])).to be(true)
      end

      it "creates an sso_login audit log entry" do
        assertion = encode(valid_payload)

        expect { post_exchange(assertion) }.to change(AuditLog, :count).by(1)
        log = AuditLog.last
        expect(log.action).to eq("sso_login")
        expect(log.metadata["source"]).to eq("turboapp")
      end
    end

    context "when the account already exists (same role)" do
      let!(:existing) { create(:account, email: email, account_type: :practitioner) }

      it "logs in without creating a new account" do
        assertion = encode(valid_payload)

        expect { post_exchange(assertion) }.not_to change(Account, :count)

        expect(response).to have_http_status(:created)
        expect(json_body.dig("data", "account", "id")).to eq(existing.id)
      end

      it "provisionne le cabinet HDS si le compte existait sans membership" do
        payload     = valid_payload
        assertion   = encode(payload)
        accounts_before = Account.count

        expect { post_exchange(assertion) }.to change(Organization, :count).by(1)
          .and change(Membership, :count).by(1)
          .and change(Practitioner, :count).by(1)

        expect(Account.count).to eq(accounts_before)

        org = Organization.find_by!(turboapp_merchant_id: payload[:merchant_id])
        expect(org.name).to eq("Cabinet Martin")
        expect(existing.reload.memberships.active.pluck(:organization_id)).to include(org.id)
      end
    end

    context "when merchant_id is absent from the assertion" do
      it "does not create an organization (retrocompat)" do
        payload     = valid_payload.except(:merchant_id)
        assertion   = encode(payload)
        org_before  = Organization.count

        expect { post_exchange(assertion) }.to change(Account, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(Organization.count).to eq(org_before)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Missing / malformed assertion
  # ---------------------------------------------------------------------------
  describe "with a missing assertion" do
    it "returns 400 missing_assertion" do
      post "/api/v1/auth/sso/exchange",
           params: {}.to_json,
           headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json_body.dig("error", "code")).to eq("missing_assertion")
    end
  end

  describe "with a malformed assertion" do
    it "returns 401 invalid_assertion" do
      post_exchange("not-a-jwt")

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end
  end

  # ---------------------------------------------------------------------------
  # Signature / claims
  # ---------------------------------------------------------------------------
  describe "with a wrong signing secret" do
    it "returns 401 invalid_assertion" do
      assertion = encode(valid_payload, secret: "b" * 64)

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end

    it "does not create any account" do
      assertion = encode(valid_payload, secret: "b" * 64)

      expect { post_exchange(assertion) }.not_to change(Account, :count)
    end
  end

  describe "with an invalid issuer" do
    it "returns 401" do
      assertion = encode(valid_payload(iss: "attacker"))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end
  end

  describe "with an invalid audience" do
    it "returns 401" do
      assertion = encode(valid_payload(aud: "other-app"))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "with cabinet_access claim" do
    it "rejects when cabinet_access is false" do
      assertion = encode(valid_payload(cabinet_access: false))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end

    it "accepts when cabinet_access is true" do
      assertion = encode(valid_payload(cabinet_access: true))

      expect { post_exchange(assertion) }.to change(Account, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "with an expired assertion" do
    it "returns 401 assertion_expired" do
      assertion = encode(valid_payload(exp: 1.minute.ago.to_i))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("assertion_expired")
    end
  end

  describe "without a jti claim" do
    it "returns 401 invalid_assertion" do
      payload = valid_payload.except(:jti)
      assertion = encode(payload)

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end
  end

  # ---------------------------------------------------------------------------
  # Anti-replay (jti denylist)
  # ---------------------------------------------------------------------------
  describe "replay protection" do
    it "rejects a second use of the same assertion" do
      payload   = valid_payload
      assertion = encode(payload)

      post_exchange(assertion)
      expect(response).to have_http_status(:created)

      post_exchange(assertion)
      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end
  end

  # ---------------------------------------------------------------------------
  # Role validation
  # ---------------------------------------------------------------------------
  describe "role validation" do
    context "without role claim" do
      it "returns 401 invalid_assertion" do
        payload   = valid_payload.except(:role)
        assertion = encode(payload)

        post_exchange(assertion)

        expect(response).to have_http_status(:unauthorized)
        expect(json_body.dig("error", "code")).to eq("invalid_assertion")
      end
    end

    context "with a non-whitelisted role (e.g. admin)" do
      it "returns 401 invalid_assertion" do
        assertion = encode(valid_payload(role: "admin"))

        post_exchange(assertion)

        expect(response).to have_http_status(:unauthorized)
        expect(json_body.dig("error", "code")).to eq("invalid_assertion")
      end

      it "does not provision an account" do
        assertion = encode(valid_payload(role: "admin"))

        expect { post_exchange(assertion) }.not_to change(Account, :count)
      end
    end

    context "with patient role (not allowed via SSO)" do
      it "returns 401" do
        assertion = encode(valid_payload(role: "patient"))

        post_exchange(assertion)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Account type mismatch protection
  # ---------------------------------------------------------------------------
  describe "account_type mismatch" do
    let!(:existing_patient) { create(:account, :patient_type, email: email) }

    it "returns 403 account_type_mismatch when existing account has different type" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("account_type_mismatch")
    end

    it "does not issue tokens" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(json_body.dig("data", "access_token")).to be_nil
    end

    it "does not upgrade the existing account" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(existing_patient.reload.account_type).to eq("patient")
    end

    it "logs an sso_account_type_mismatch audit entry" do
      assertion = encode(valid_payload)

      expect { post_exchange(assertion) }.to change(AuditLog, :count).by(1)
      expect(AuditLog.last.action).to eq("sso_account_type_mismatch")
    end
  end

  # ---------------------------------------------------------------------------
  # Inactive accounts
  # ---------------------------------------------------------------------------
  describe "with an inactive existing account" do
    let!(:inactive) { create(:account, email: email, account_type: :practitioner, active: false) }

    it "returns 403 account_inactive" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("account_inactive")
    end

    it "does not issue tokens" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(json_body.dig("data", "access_token")).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Issued tokens are usable
  # ---------------------------------------------------------------------------
  describe "issued tokens usability" do
    it "produces an access_token verifiable by Auth::TokenVerifier" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      access_token = json_body.dig("data", "access_token")
      payload = ::Auth::TokenVerifier.verify!(access_token)

      expect(payload["account_type"]).to eq("practitioner")
    end
  end

  # ---------------------------------------------------------------------------
  # Email validation
  # ---------------------------------------------------------------------------
  describe "email validation" do
    it "rejects an assertion with a blank sub" do
      assertion = encode(valid_payload(sub: ""))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end

    it "rejects an assertion with an invalid email format" do
      assertion = encode(valid_payload(sub: "not-an-email"))

      post_exchange(assertion)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("invalid_assertion")
    end

    it "does not create an account on invalid email" do
      assertion = encode(valid_payload(sub: "bad email"))

      expect { post_exchange(assertion) }.not_to change(Account, :count)
    end
  end

  # ---------------------------------------------------------------------------
  # MFA propagation
  # ---------------------------------------------------------------------------
  describe "MFA claim propagation" do
    it "issues a token with mfa_verified: false by default" do
      assertion = encode(valid_payload)

      post_exchange(assertion)

      expect(json_body.dig("data", "mfa_verified")).to eq(false)
      payload = ::Auth::TokenVerifier.verify!(json_body.dig("data", "access_token"))
      expect(payload["mfa_verified"]).to eq(false)
    end

    it "propagates mfa: true from the assertion into the access token" do
      assertion = encode(valid_payload(mfa: true))

      post_exchange(assertion)

      expect(json_body.dig("data", "mfa_verified")).to eq(true)
      payload = ::Auth::TokenVerifier.verify!(json_body.dig("data", "access_token"))
      expect(payload["mfa_verified"]).to eq(true)
    end

    it "treats mfa: 'true' (string) as unverified (strict comparison)" do
      assertion = encode(valid_payload(mfa: "true"))

      post_exchange(assertion)

      expect(json_body.dig("data", "mfa_verified")).to eq(false)
    end
  end
end
