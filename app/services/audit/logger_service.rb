# frozen_string_literal: true

module Audit
  class LoggerService
    # Fire-and-forget audit logging.
    # Never raises – a failure to log must not interrupt the main request.
    def self.log(action:, account: nil, organization: nil, resource: nil, metadata: {}, request: nil)
      scrubbed = MetadataScrubber.call(metadata).merge("timestamp" => Time.current.iso8601)

      AuditLog.create!(
        account_id:      account&.id,
        organization_id: organization&.id,
        action:          action.to_s,
        resource_type:   resource&.class&.name,
        resource_id:     resource&.id,
        ip_address:      request&.remote_ip,
        user_agent:      request&.user_agent&.first(512),
        metadata:        scrubbed
      )
    rescue => e
      Rails.logger.error("[AuditLog] Failed to write audit event '#{action}': #{e.class}")
    end
  end
end
