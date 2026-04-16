# frozen_string_literal: true

# Treatment quote. States: draft → sent → signed | rejected | expired
# Amounts are FROZEN at send time – no recalculation if fee schedules change.
# Once sent, line items become immutable.
class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.references :patient_record, null: false, foreign_key: true, index: true
      t.references :practitioner,   null: false, foreign_key: true, index: true
      t.references :organization,   null: false, foreign_key: true, index: true

      t.string :quote_number, null: false
      t.string :status, null: false, default: "draft"
      t.date   :valid_until

      # Totals frozen at send time
      t.decimal :total_fees,              precision: 10, scale: 2, default: "0.0"
      t.decimal :total_reimbursement_base, precision: 10, scale: 2, default: "0.0"
      t.decimal :total_patient_share,     precision: 10, scale: 2, default: "0.0"

      t.text :notes

      # External signature (Docuseal or equivalent)
      t.string   :signature_submission_id

      # Transition timestamps
      t.datetime :sent_at
      t.datetime :signed_at
      t.datetime :rejected_at
      t.datetime :expired_at

      t.timestamps null: false
    end

    add_index :quotes, :quote_number, unique: true
    add_index :quotes, :status
    add_index :quotes, :signature_submission_id
  end
end
