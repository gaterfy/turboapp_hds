# frozen_string_literal: true

class DeviseCreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # Lockable – blocks account after N failed attempts (HDS requirement)
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      # HDS custom fields
      t.integer  :account_type, null: false, default: 0  # enum: practitioner, patient
      t.boolean  :active, null: false, default: true
      # Rotated on logout-all / password change to invalidate all issued tokens
      t.string   :jti_secret, null: false, default: -> { "gen_random_uuid()" }

      t.timestamps null: false
    end

    add_index :accounts, :email, unique: true
    add_index :accounts, :reset_password_token, unique: true
    add_index :accounts, :unlock_token, unique: true
    add_index :accounts, :jti_secret, unique: true
    add_index :accounts, :account_type
    add_index :accounts, :active
  end
end
