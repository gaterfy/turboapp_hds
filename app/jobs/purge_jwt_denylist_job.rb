# frozen_string_literal: true

# Removes JwtDenylist rows whose `exp` is in the past.
# Rows past their expiry can never match a currently-valid access token
# (the JWT itself would be expired), so keeping them serves no purpose.
class PurgeJwtDenylistJob < ApplicationJob
  queue_as :background

  def perform
    deleted = JwtDenylist.purge_expired!
    Rails.logger.info("[PurgeJwtDenylistJob] purged #{deleted} expired entries")
  end
end
