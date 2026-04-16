# frozen_string_literal: true

# Append-only table. Never update or delete rows.
class AuditLog < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :organization, optional: true

  AUTH_ACTIONS = %w[
    login_success
    login_failure
    logout
    token_refreshed
    token_revoked
    password_reset_requested
    password_reset_completed
    account_locked
    account_unlocked
  ].freeze

  RESOURCE_ACTIONS = %w[
    read
    created
    updated
    deleted
    status_changed
    role_changed
  ].freeze

  validates :action, presence: true

  # Prevent accidental updates to audit records
  before_update { raise ActiveRecord::ReadOnlyRecord, "AuditLog records are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "AuditLog records cannot be deleted" }
end
