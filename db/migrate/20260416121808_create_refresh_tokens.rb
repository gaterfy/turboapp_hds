# frozen_string_literal: true

class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :revoked_reason
      # Context at issuance – used for audit and anomaly detection
      t.string :issued_ip
      t.string :issued_user_agent

      t.timestamps null: false
    end

    add_index :refresh_tokens, :token, unique: true
    add_index :refresh_tokens, :expires_at
    add_index :refresh_tokens, :revoked_at
  end
end
