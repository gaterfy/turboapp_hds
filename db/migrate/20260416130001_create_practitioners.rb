# frozen_string_literal: true

class CreatePractitioners < ActiveRecord::Migration[8.0]
  def change
    create_table :practitioners do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      # account_id is required for practitioners – they need portal access
      t.references :account, null: false, foreign_key: true, index: true

      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :email,      null: false
      t.string :phone

      t.string :specialization,  null: false
      t.string :license_number,  null: false
      # clinical_role: dentist | orthodontist | surgeon | assistant | hygienist | owner
      t.string :clinical_role, null: false, default: "dentist"
      t.string :status,        null: false, default: "active"

      t.string  :avatar
      t.jsonb   :working_hours, null: false, default: []
      t.text    :skills,        array: true, default: []
      t.decimal :rating,        precision: 3, scale: 2
      t.integer :total_reviews, default: 0

      t.timestamps null: false
    end

    add_index :practitioners, :email
    add_index :practitioners, :status
    add_index :practitioners, :clinical_role
    add_index :practitioners, [ :license_number, :organization_id ], unique: true
  end
end
