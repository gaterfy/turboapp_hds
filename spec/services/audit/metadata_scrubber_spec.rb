# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::MetadataScrubber do
  before { allow(ENV).to receive(:[]).and_call_original }
  before { allow(ENV).to receive(:[]).with("AUDIT_EMAIL_PEPPER").and_return("spec-pepper") }

  it "hashes string values that look like an email" do
    out = described_class.call(merchant_email: "dr.martin@example.com")

    expect(out["merchant_email"]).to start_with("email_sha256:")
    expect(out["merchant_email"]).not_to include("dr.martin")
  end

  it "produces stable hashes for the same email (case-insensitive)" do
    a = described_class.call(email: "Dr.Martin@Example.com")
    b = described_class.call(email: "dr.martin@example.com")

    expect(a["email"]).to eq(b["email"])
  end

  it "differs when the pepper differs" do
    out1 = described_class.call(email: "a@b.fr")
    allow(ENV).to receive(:[]).with("AUDIT_EMAIL_PEPPER").and_return("OTHER")
    out2 = described_class.call(email: "a@b.fr")

    expect(out1["email"]).not_to eq(out2["email"])
  end

  it "filters known secret-like keys" do
    out = described_class.call(
      access_token: "abc",
      refresh_token: "xyz",
      otp_code: "123456",
      mfa_secret: "base32stuff",
      assertion: "eyJhbGc..."
    )

    expect(out.values).to all(eq("[FILTERED]"))
  end

  it "keeps non-sensitive scalars as-is" do
    out = described_class.call(source: "turboapp", mfa_verified: true, count: 3)

    expect(out).to include("source" => "turboapp", "mfa_verified" => true, "count" => 3)
  end

  it "recursively scrubs nested hashes" do
    out = described_class.call(
      outer: { inner_email: "a@b.fr", inner_token: "top-secret" }
    )

    expect(out["outer"]["inner_email"]).to start_with("email_sha256:")
    expect(out["outer"]["inner_token"]).to eq("[FILTERED]")
  end

  it "handles arrays" do
    out = described_class.call(recipients: %w[a@b.fr c@d.fr])

    expect(out["recipients"]).to all(start_with("email_sha256:"))
  end

  it "accepts nil metadata" do
    expect(described_class.call(nil)).to eq({})
  end
end
