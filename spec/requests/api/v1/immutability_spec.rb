# frozen_string_literal: true

require "rails_helper"

# ─────────────────────────────────────────────────────────────────────────────
# These specs verify the core HDS invariant: once a clinical or financial
# document is finalised, its content can never be altered.
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe "Immutability invariants", type: :request do
  let(:org)        { create(:organization) }
  let(:account)    { create(:account) }
  let!(:membership) { create(:membership, account: account, organization: org, role: :practitioner) }
  let(:practitioner) { create(:practitioner, account: account, organization: org) }
  let(:patient)      { create(:patient, organization: org) }
  let(:record)       { create(:patient_record, patient: patient, organization: org) }
  let(:headers)      { api_headers(account, org) }

  # -------------------------------------------------------------------------
  # CONSULTATION: clinical fields must not change after completion
  #
  # The policy (ConsultationPolicy#update?) returns false for any non-editable
  # consultation → Pundit raises NotAuthorizedError → 403.
  # Both 403 and 422 uphold the HDS invariant; 403 is stricter (no info leak).
  # -------------------------------------------------------------------------
  describe "Consultation" do
    let!(:consultation) do
      create(:consultation, :completed,
             patient_record: record,
             organization: org,
             practitioner: practitioner)
    end

    it "rejects changes to clinical fields when status is completed (403 via policy)" do
      patch "/api/v1/consultations/#{consultation.id}",
            params: { consultation: { chief_complaint: "TAMPERED" } }.to_json,
            headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(consultation.reload.chief_complaint).not_to eq("TAMPERED")
    end

    it "rejects changes to all clinical fields on a completed consultation" do
      %w[observations diagnosis notes].each do |field|
        patch "/api/v1/consultations/#{consultation.id}",
              params: { consultation: { field => "tampered" } }.to_json,
              headers: headers

        expect(response.status).to be_in([403, 422]),
          "Expected 403 or 422 when changing #{field} on a completed consultation, got #{response.status}"
      end
    end

    context "when consultation is locked (sealed)" do
      let!(:locked_consultation) do
        create(:consultation, :locked,
               patient_record: record,
               organization: org,
               practitioner: practitioner)
      end

      it "also rejects clinical edits" do
        patch "/api/v1/consultations/#{locked_consultation.id}",
              params: { consultation: { chief_complaint: "TAMPERED" } }.to_json,
              headers: headers

        expect(response.status).to be_in([403, 422])
        expect(locked_consultation.reload.chief_complaint).not_to eq("TAMPERED")
      end
    end
  end

  # -------------------------------------------------------------------------
  # QUOTE: line items cannot be added/modified/deleted once sent
  #
  # Setup: create line item while quote is DRAFT, then freeze it via SQL
  # to avoid the callback blocking the test setup itself.
  # -------------------------------------------------------------------------
  describe "Quote" do
    # Build as draft, add a line item, then mark as sent via SQL (bypass callback)
    let!(:quote_with_item) do
      q = create(:quote, patient_record: record, organization: org, practitioner: practitioner)
      q.line_items.create!(procedure_code: "D0120", label: "Exam", quantity: 1, unit_fee: 50)
      q.update_columns(status: "sent", sent_at: Time.current)
      q
    end

    it "prevents adding a new line item to a sent quote" do
      post "/api/v1/quotes/#{quote_with_item.id}/line_items",
           params: {
             line_item: {
               procedure_code: "D9999",
               label: "Tampered item",
               quantity: 1,
               unit_fee: "500.00"
             }
           }.to_json,
           headers: headers

      # Policy (manage_line_items?) blocks it → 403; model callback → 422
      expect(response.status).to be_in([403, 422])
      expect(quote_with_item.line_items.reload.count).to eq(1)
    end

    it "prevents modifying a line item on a sent quote" do
      line_item = quote_with_item.line_items.first

      patch "/api/v1/quotes/#{quote_with_item.id}/line_items/#{line_item.id}",
            params: { line_item: { unit_fee: "999.00" } }.to_json,
            headers: headers

      expect(response.status).to be_in([403, 422])
      expect(line_item.reload.unit_fee.to_f).not_to eq(999.0)
    end

    it "prevents deleting a line item on a sent quote" do
      line_item = quote_with_item.line_items.first

      delete "/api/v1/quotes/#{quote_with_item.id}/line_items/#{line_item.id}",
             headers: headers

      expect(response.status).to be_in([403, 422])
      expect { line_item.reload }.not_to raise_error
    end
  end

  # -------------------------------------------------------------------------
  # PRESCRIPTION: line items locked once prescription is signed
  # -------------------------------------------------------------------------
  describe "Prescription" do
    let!(:signed_prescription) do
      p = create(:prescription, patient_record: record, organization: org, practitioner: practitioner)
      p.update_columns(status: "signed", signed_at: Time.current)
      p
    end

    it "prevents adding a line item to a signed prescription" do
      post "/api/v1/prescriptions/#{signed_prescription.id}/line_items",
           params: {
             line_item: {
               medication: "Amoxicillin",
               dosage: "500mg",
               quantity: 2,
               renewable: false
             }
           }.to_json,
           headers: headers

      expect(response.status).to be_in([403, 422])
    end
  end
end
