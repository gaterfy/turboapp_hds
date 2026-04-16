# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      # account_id is nullable: some events occur before or outside authentication
      t.bigint :account_id
      t.bigint :organization_id
      t.string :action, null: false
      t.string :resource_type
      t.bigint :resource_id
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, null: false, default: {}

      # audit_logs are append-only – no updated_at
      t.datetime :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :audit_logs, :account_id
    add_index :audit_logs, :organization_id
    add_index :audit_logs, :action
    add_index :audit_logs, [ :resource_type, :resource_id ]
    add_index :audit_logs, :created_at
  end
end
