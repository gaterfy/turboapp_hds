# frozen_string_literal: true

class CreatePatients < ActiveRecord::Migration[8.0]
  def change
    create_table :patients do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      # account_id is nullable: a patient may not have portal access yet
      t.references :account, null: true, foreign_key: true, index: true

      t.string :first_name,  null: false
      t.string :last_name,   null: false
      t.string :email,       null: false
      t.string :phone
      t.string :mobile
      t.date   :birth_date,  null: false
      t.string :gender
      t.string :address
      t.string :city
      t.string :postal_code
      t.string :country

      # Sensitive – should be encrypted at rest in a future sprint
      t.string :social_security_number
      t.string :insurance_provider
      t.string :insurance_number

      t.string :emergency_contact
      t.string :emergency_phone
      t.text   :notes

      t.string :status, null: false, default: "active"

      t.timestamps null: false
    end

    add_index :patients, :status
    add_index :patients, [ :organization_id, :email ]
    # A patient (by email) can be in several organizations, but only once per org
    add_index :patients, [ :organization_id, :email ], unique: true, name: "idx_patients_org_email_unique"
  end
end
