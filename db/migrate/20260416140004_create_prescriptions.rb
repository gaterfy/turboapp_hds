# frozen_string_literal: true

# Medical prescription. States: draft → signed → delivered → cancelled
# Only a practitioner may sign. Once signed, content is frozen.
class CreatePrescriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :prescriptions do |t|
      t.references :patient_record, null: false, foreign_key: true, index: true
      t.references :practitioner,   null: false, foreign_key: true, index: true
      t.references :consultation,   null: true,  foreign_key: true, index: true
      t.references :organization,   null: false, foreign_key: true, index: true

      t.string :prescription_number, null: false
      t.date   :prescription_date,   null: false
      t.string :status, null: false, default: "draft"

      t.text :notes

      # External signature
      t.string :signature_submission_id

      # Transition timestamps
      t.datetime :signed_at
      t.datetime :delivered_at
      t.datetime :cancelled_at

      t.timestamps null: false
    end

    add_index :prescriptions, :prescription_number, unique: true
    add_index :prescriptions, :status
    add_index :prescriptions, :prescription_date
  end
end
