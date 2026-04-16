# frozen_string_literal: true

require "rails_helper"

# ─────────────────────────────────────────────────────────────────────────────
# Tenant isolation: an account from Org A must NEVER access data from Org B.
# Each scenario verifies that policy_scope and controller scoping enforce
# the organization boundary.
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe "Tenant isolation", type: :request do
  # Org A – the requesting user belongs here
  let(:org_a)       { create(:organization) }
  let(:account_a)   { create(:account) }
  let!(:membership_a) { create(:membership, account: account_a, organization: org_a, role: :practitioner) }
  let(:practitioner_a) { create(:practitioner, account: account_a, organization: org_a) }
  let(:headers_a)   { api_headers(account_a, org_a) }

  # Org B – a completely separate tenant
  let(:org_b)       { create(:organization) }
  let(:account_b)   { create(:account) }
  let!(:membership_b) { create(:membership, account: account_b, organization: org_b, role: :practitioner) }
  let(:practitioner_b) { create(:practitioner, account: account_b, organization: org_b) }

  # -------------------------------------------------------------------------
  # Patients
  # -------------------------------------------------------------------------
  describe "Patients" do
    let!(:patient_b) { create(:patient, organization: org_b) }

    it "does not return patients from a different org in the index" do
      get "/api/v1/patients", headers: headers_a

      expect(response).to have_http_status(:ok)
      # patients controller wraps in { patients: [...], meta: {...} }
      ids = json_body.dig("data", "patients")&.map { |p| p["id"] } || []
      expect(ids).not_to include(patient_b.id)
    end

    it "returns 404 when attempting to access a patient from another org" do
      get "/api/v1/patients/#{patient_b.id}", headers: headers_a

      expect(response).to have_http_status(:not_found)
    end
  end

  # -------------------------------------------------------------------------
  # Patient Records
  # -------------------------------------------------------------------------
  describe "Patient Records" do
    let!(:patient_b)        { create(:patient, organization: org_b) }
    let!(:patient_record_b) { create(:patient_record, patient: patient_b, organization: org_b) }

    it "does not expose patient records from another org in index" do
      get "/api/v1/patient_records", headers: headers_a

      expect(response).to have_http_status(:ok)
      # patient_records controller renders array directly in data
      ids = Array(json_body["data"]).map { |r| r["id"] }
      expect(ids).not_to include(patient_record_b.id)
    end

    it "returns 404 when accessing a patient record from another org" do
      get "/api/v1/patient_records/#{patient_record_b.id}", headers: headers_a

      expect(response).to have_http_status(:not_found)
    end
  end

  # -------------------------------------------------------------------------
  # Consultations
  # -------------------------------------------------------------------------
  describe "Consultations" do
    let!(:patient_b)      { create(:patient, organization: org_b) }
    let!(:record_b)       { create(:patient_record, patient: patient_b, organization: org_b) }
    let!(:consultation_b) { create(:consultation, patient_record: record_b, organization: org_b, practitioner: practitioner_b) }

    it "does not expose consultations from another org in index" do
      get "/api/v1/consultations", headers: headers_a

      expect(response).to have_http_status(:ok)
      # consultations controller wraps in { consultations: [...], meta: {...} }
      ids = json_body.dig("data", "consultations")&.map { |c| c["id"] } || []
      expect(ids).not_to include(consultation_b.id)
    end

    it "returns 404 when accessing a consultation from another org" do
      get "/api/v1/consultations/#{consultation_b.id}", headers: headers_a

      expect(response).to have_http_status(:not_found)
    end
  end

  # -------------------------------------------------------------------------
  # X-Organization-Id header forgery attempt
  # -------------------------------------------------------------------------
  describe "Header spoofing" do
    it "rejects a request when the account has no membership in the claimed org" do
      get "/api/v1/patients",
          headers: api_headers(account_a, org_a).merge("X-Organization-Id" => org_b.id.to_s)

      # The account has no membership in org_b → 403
      expect(response).to have_http_status(:forbidden)
    end
  end
end
