# frozen_string_literal: true

# Individual line of a Quote.
# Becomes immutable once the parent Quote transitions out of :draft.
class CreateQuoteLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_line_items do |t|
      t.references :quote, null: false, foreign_key: true, index: true

      t.string  :procedure_code        # code CCAM equivalent
      t.string  :label, null: false
      t.string  :tooth_location        # localisation
      t.integer :quantity, null: false, default: 1
      t.integer :position, null: false, default: 0

      # Amounts – frozen when quote is sent
      t.decimal :unit_fee,           precision: 10, scale: 2, null: false
      t.decimal :reimbursement_base, precision: 10, scale: 2, default: "0.0"
      t.decimal :reimbursement_rate, precision: 5,  scale: 2, default: "0.0"
      t.decimal :reimbursement_amount, precision: 10, scale: 2, default: "0.0"
      t.decimal :patient_share,      precision: 10, scale: 2, default: "0.0"
      t.decimal :overage,            precision: 10, scale: 2, default: "0.0"

      t.timestamps null: false
    end

    add_index :quote_line_items, [ :quote_id, :position ]
  end
end
