# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :organization, null: false, foreign_key: true, index: true
      t.integer :role, null: false, default: 0  # enum: practitioner, admin, assistant
      t.boolean :active, null: false, default: true
      t.datetime :joined_at, null: false, default: -> { "NOW()" }

      t.timestamps null: false
    end

    add_index :memberships, [ :account_id, :organization_id ], unique: true
    add_index :memberships, [ :organization_id, :role ]
    add_index :memberships, :active
  end
end
