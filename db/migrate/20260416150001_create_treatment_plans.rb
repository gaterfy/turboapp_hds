class CreateTreatmentPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :treatment_plans do |t|
      t.references :patient_record,  null: false, foreign_key: true
      t.references :practitioner,    null: false, foreign_key: true
      t.references :organization,    null: false, foreign_key: true

      t.string  :title,           null: false
      t.text    :description
      t.string  :status,          null: false, default: "proposed"
      t.integer :session_count
      t.decimal :estimated_total, precision: 10, scale: 2, default: "0.0"
      t.decimal :accepted_total,  precision: 10, scale: 2

      t.datetime :accepted_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :treatment_plans, :status

    create_table :treatment_plan_items do |t|
      t.references :treatment_plan, null: false, foreign_key: true

      t.string  :procedure_code
      t.string  :label,      null: false
      t.string  :tooth_ref               # FDI notation e.g. "16", "26"
      t.integer :quantity,   null: false, default: 1
      t.decimal :unit_fee,   null: false, precision: 10, scale: 2
      t.integer :position,   null: false, default: 0
      t.text    :notes
      t.boolean :completed,  null: false, default: false

      t.timestamps
    end

    add_index :treatment_plan_items, :position
  end
end
