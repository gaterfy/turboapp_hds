# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Treatment Plans API", type: :request do
  let(:org)           { create(:organization) }
  let(:account)       { create(:account) }
  let!(:membership)   { create(:membership, account: account, organization: org, role: :practitioner) }
  let!(:practitioner) { create(:practitioner, account: account, organization: org) }
  let(:patient)       { create(:patient, organization: org) }
  let(:record)        { create(:patient_record, patient: patient, organization: org) }
  let(:headers)      { api_headers(account, org) }

  describe "GET /api/v1/treatment_plans" do
    let!(:plan) { create(:treatment_plan, patient_record: record, organization: org, practitioner: practitioner) }

    it "returns plans scoped to the organization" do
      other_org  = create(:organization)
      other_acct = create(:account)
      other_prac = create(:practitioner, account: other_acct, organization: other_org)
      create(:membership, account: other_acct, organization: other_org)
      other_patient = create(:patient, organization: other_org)
      other_record  = create(:patient_record, patient: other_patient, organization: other_org)
      other_plan    = create(:treatment_plan, patient_record: other_record, organization: other_org, practitioner: other_prac)

      get "/api/v1/treatment_plans", headers: headers

      expect(response).to have_http_status(:ok)
      ids = json_body.dig("data", "treatment_plans")&.map { |p| p["id"] } || []
      expect(ids).to include(plan.id)
      expect(ids).not_to include(other_plan.id)
    end
  end

  describe "POST /api/v1/treatment_plans" do
    it "creates a plan in proposed status" do
      post "/api/v1/treatment_plans",
           params: {
             patient_record_id: record.id,
             treatment_plan: {
               title:           "Rehabilitation plan",
               description:     "Multi-step",
               session_count:   3,
               estimated_total: "900.00"
             }
           }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_body.dig("data", "status")).to eq("proposed")
      expect(json_body.dig("data", "title")).to eq("Rehabilitation plan")
    end
  end

  describe "PATCH /api/v1/treatment_plans/:id/accept" do
    let!(:plan) { create(:treatment_plan, patient_record: record, organization: org, practitioner: practitioner) }

    it "transitions plan to accepted and freezes the total" do
      patch "/api/v1/treatment_plans/#{plan.id}/accept", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "status")).to eq("accepted")
      expect(json_body.dig("data", "accepted_total")).to be_present
    end

    it "prevents accepting an already accepted plan (403 via policy)" do
      plan.accept!
      patch "/api/v1/treatment_plans/#{plan.id}/accept", headers: headers

      # Policy (accept?) checks may_accept? → false → Pundit 403
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Plan item immutability" do
    let!(:accepted_plan) do
      p = create(:treatment_plan, patient_record: record, organization: org, practitioner: practitioner)
      p.accept!
      p
    end

    it "prevents adding items to an accepted plan" do
      post "/api/v1/treatment_plans/#{accepted_plan.id}/items",
           params: { item: { label: "Implant", quantity: 1, unit_fee: "500.00" } }.to_json,
           headers: headers

      expect(response.status).to be_in([403, 422])
    end
  end
end
