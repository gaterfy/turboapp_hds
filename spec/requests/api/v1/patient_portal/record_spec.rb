# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Patient Portal", type: :request do
  let(:org)           { create(:organization) }
  let(:patient_acct)  { create(:account, account_type: :patient) }
  let!(:membership)   { create(:membership, account: patient_acct, organization: org, role: :assistant) }
  let(:patient)       { create(:patient, organization: org, account: patient_acct) }
  let!(:record)       { create(:patient_record, patient: patient, organization: org) }
  let(:headers)       { api_headers(patient_acct, org) }

  # ─── Access control ──────────────────────────────────────────────────────
  context "when accessed by a practitioner account" do
    let(:prac_account) { create(:account, account_type: :practitioner) }
    let!(:prac_membership) { create(:membership, account: prac_account, organization: org) }
    let(:prac_headers) { api_headers(prac_account, org) }

    it "returns 403" do
      get "/api/v1/patient_portal/record", headers: prac_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── Own record ──────────────────────────────────────────────────────────
  describe "GET /api/v1/patient_portal/record" do
    it "returns the patient's own record" do
      get "/api/v1/patient_portal/record", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "id")).to eq(record.id)
    end

    it "does not return another patient's record" do
      other_patient = create(:patient, organization: org)
      create(:patient_record, patient: other_patient, organization: org)

      get "/api/v1/patient_portal/record", headers: headers

      expect(json_body.dig("data", "id")).to eq(record.id)
    end
  end

  # ─── Consultations (finalized only) ──────────────────────────────────────
  describe "GET /api/v1/patient_portal/record/consultations" do
    let(:practitioner) { create(:practitioner, organization: org) }
    let!(:completed_c) { create(:consultation, :completed, patient_record: record, organization: org, practitioner: practitioner) }
    let!(:draft_c)     { create(:consultation, patient_record: record, organization: org, practitioner: practitioner) }

    it "returns only finalized consultations" do
      get "/api/v1/patient_portal/record/consultations", headers: headers

      expect(response).to have_http_status(:ok)
      ids = json_body.dig("data", "consultations")&.map { |c| c["id"] } || []
      expect(ids).to include(completed_c.id)
      expect(ids).not_to include(draft_c.id)
    end
  end

  # ─── Quotes (sent/signed only) ────────────────────────────────────────────
  describe "GET /api/v1/patient_portal/record/quotes" do
    let(:practitioner) { create(:practitioner, organization: org) }
    let!(:sent_quote)  { create(:quote, :sent, patient_record: record, organization: org, practitioner: practitioner) }
    let!(:draft_quote) { create(:quote, patient_record: record, organization: org, practitioner: practitioner) }

    it "returns only non-draft quotes" do
      get "/api/v1/patient_portal/record/quotes", headers: headers

      expect(response).to have_http_status(:ok)
      ids = json_body.dig("data", "quotes")&.map { |q| q["id"] } || []
      expect(ids).to include(sent_quote.id)
      expect(ids).not_to include(draft_quote.id)
    end
  end
end
