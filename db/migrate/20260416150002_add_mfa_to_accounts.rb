class AddMfaToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :mfa_secret,      :string
    add_column :accounts, :mfa_enabled,     :boolean, null: false, default: false
    add_column :accounts, :mfa_enabled_at,  :datetime
    add_column :accounts, :mfa_backup_codes, :text, array: true, default: []

    add_index :accounts, :mfa_enabled
  end
end
