# frozen_string_literal: true

# Supprime les entrees expirees de la SSO assertion denylist.
# Executee periodiquement via solid_queue (config/recurring.yml).
#
# Les assertions ont un TTL de 60s, donc apres ce TTL le JTI n'a plus besoin
# d'etre conserve : une assertion avec ce JTI sera rejetee pour cause
# d'expiration bien avant d'etre testee contre la denylist.
class PurgeSsoAssertionDenylistJob < ApplicationJob
  queue_as :background

  def perform
    deleted = SsoAssertionDenylist.purge_expired!
    Rails.logger.info("[PurgeSsoAssertionDenylistJob] purged #{deleted} expired entries")
  end
end
