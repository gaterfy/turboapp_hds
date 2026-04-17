# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth::Memberships", type: :request do
  let(:account) { create(:account, account_type: :practitioner) }

  let(:org_a) { create(:organization, name: "Cabinet Alpha") }
  let(:org_b) { create(:organization, name: "Cabinet Beta") }

  let(:headers) { auth_headers_for(account) }

  describe "GET /api/v1/auth/memberships" do
    context "with valid JWT and at least one active membership" do
      before do
        create(:membership, account: account, organization: org_a, role: :practitioner)
        create(:membership, account: account, organization: org_b, role: :admin)
      end

      it "returns the list of organizations the account belongs to" do
        get "/api/v1/auth/memberships", headers: headers

        expect(response).to have_http_status(:ok)
        data = json_body["data"]
        expect(data.size).to eq(2)
        slugs = data.map { |m| m["slug"] }
        expect(slugs).to include(org_a.slug, org_b.slug)
        expect(data.first.keys).to include("organization_id", "name", "slug", "role", "joined_at")
      end

      it "does not require X-Organization-Id" do
        get "/api/v1/auth/memberships", headers: headers
        expect(response).not_to have_http_status(:bad_request)
      end
    end

    context "filtering" do
      it "excludes inactive memberships" do
        create(:membership, account: account, organization: org_a, active: true)
        create(:membership, account: account, organization: org_b, active: false)

        get "/api/v1/auth/memberships", headers: headers
        data = json_body["data"]
        expect(data.size).to eq(1)
        expect(data.first["slug"]).to eq(org_a.slug)
      end

      it "excludes memberships pointing to inactive organizations" do
        create(:membership, account: account, organization: org_a)
        org_b.update!(active: false)
        create(:membership, account: account, organization: org_b)

        get "/api/v1/auth/memberships", headers: headers
        data = json_body["data"]
        expect(data.size).to eq(1)
        expect(data.first["slug"]).to eq(org_a.slug)
      end
    end

    context "with no memberships" do
      it "returns an empty array (not an error)" do
        get "/api/v1/auth/memberships", headers: headers
        expect(response).to have_http_status(:ok)
        expect(json_body["data"]).to eq([])
      end
    end

    context "authentication" do
      it "rejects when Authorization header is missing" do
        get "/api/v1/auth/memberships"
        expect(response).to have_http_status(:unauthorized)
        expect(json_body.dig("error", "code")).to eq("unauthorized")
      end

      it "rejects an invalid JWT" do
        get "/api/v1/auth/memberships",
            headers: { "Authorization" => "Bearer not-a-jwt" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "MFA enforcement" do
      it "returns mfa_required when the token was not MFA-validated" do
        create(:membership, account: account, organization: org_a)
        get "/api/v1/auth/memberships",
            headers: auth_headers_for(account, mfa_verified: false)
        expect(response).to have_http_status(:forbidden)
        expect(json_body.dig("error", "code")).to eq("mfa_required")
      end
    end
  end
end
