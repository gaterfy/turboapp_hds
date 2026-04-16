# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  it "returns 200 with status ok and db check" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    body = json_body

    expect(body["status"]).to eq("ok")
    expect(body.dig("checks", "database")).to eq("ok")
    expect(body["version"]).to be_present
    expect(body["env"]).to eq("test")
  end
end
