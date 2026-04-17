# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Purge jobs", type: :job do
  describe PurgeJwtDenylistJob do
    it "deletes rows with exp in the past, keeps rows in the future" do
      JwtDenylist.create!(jti: "old-1", exp: 2.hours.ago)
      JwtDenylist.create!(jti: "old-2", exp: 1.minute.ago)
      JwtDenylist.create!(jti: "future", exp: 10.minutes.from_now)

      expect { described_class.perform_now }.to change(JwtDenylist, :count).from(3).to(1)
      expect(JwtDenylist.pluck(:jti)).to eq(["future"])
    end
  end

  describe PurgeSsoAssertionDenylistJob do
    it "deletes expired assertion denylist entries" do
      SsoAssertionDenylist.create!(jti: "old", exp: 1.hour.ago)
      SsoAssertionDenylist.create!(jti: "new", exp: 1.hour.from_now)

      expect { described_class.perform_now }.to change(SsoAssertionDenylist, :count).from(2).to(1)
    end
  end

  describe PurgeRefreshTokensJob do
    let(:account) { create(:account) }

    it "deletes expired refresh tokens" do
      rt = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)
      rt.update!(expires_at: 1.day.ago)

      expect { described_class.perform_now }.to change(RefreshToken, :count).by(-1)
    end

    it "deletes refresh tokens revoked beyond the retention window" do
      rt = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)
      rt.update_columns(revoked_at: 31.days.ago, revoked_reason: "rotated")

      expect { described_class.perform_now }.to change(RefreshToken, :count).by(-1)
    end

    it "keeps recently-revoked tokens for forensic investigation" do
      rt = ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)
      rt.revoke!(reason: "logout")

      expect { described_class.perform_now }.not_to change(RefreshToken, :count)
    end

    it "keeps valid, non-revoked refresh tokens" do
      ::Auth::TokenIssuer.issue_refresh_token(account, request: nil)

      expect { described_class.perform_now }.not_to change(RefreshToken, :count)
    end
  end
end
