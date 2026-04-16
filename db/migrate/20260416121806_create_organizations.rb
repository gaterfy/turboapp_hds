# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :settings, null: false, default: {}

      t.timestamps null: false
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, :active
  end
end
