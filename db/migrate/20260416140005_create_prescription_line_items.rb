# frozen_string_literal: true

# One medication line on a Prescription.
# Becomes immutable once the parent Prescription is signed.
class CreatePrescriptionLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :prescription_line_items do |t|
      t.references :prescription, null: false, foreign_key: true, index: true

      t.string  :medication,  null: false
      t.string  :dosage,      null: false   # posologie
      t.string  :duration
      t.integer :quantity,    null: false, default: 1
      t.boolean :renewable,   null: false, default: false
      t.integer :position,    null: false, default: 0
      t.text    :notes

      t.timestamps null: false
    end

    add_index :prescription_line_items, [ :prescription_id, :position ]
  end
end
