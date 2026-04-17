# frozen_string_literal: true

# Deletes RefreshToken rows that are either:
#   - past `expires_at` (natural 30-day expiry)
#   - revoked more than 30 days ago (useful audit window already elapsed)
#
# Revoked-but-recent tokens are kept on purpose so we can investigate
# incidents (forensic trail of revocations).
class PurgeRefreshTokensJob < ApplicationJob
  queue_as :background

  RETENTION_AFTER_REVOKE = 30.days

  def perform
    deleted_expired = RefreshToken.where("expires_at < ?", Time.current).delete_all
    deleted_revoked = RefreshToken.where.not(revoked_at: nil)
                                  .where("revoked_at < ?", RETENTION_AFTER_REVOKE.ago)
                                  .delete_all

    Rails.logger.info(
      "[PurgeRefreshTokensJob] deleted #{deleted_expired} expired + #{deleted_revoked} old-revoked tokens"
    )
  end
end
