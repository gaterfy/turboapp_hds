# frozen_string_literal: true

# Clinical encounter attached to a PatientRecord.
# States: in_progress → completed → locked
# Once locked, no clinical content may be modified.
class CreateConsultations < ActiveRecord::Migration[8.0]
  def change
    create_table :consultations do |t|
      t.references :patient_record, null: false, foreign_key: true, index: true
      t.references :practitioner,   null: false, foreign_key: true, index: true
      t.references :appointment,    null: true,  foreign_key: true, index: true
      t.references :organization,   null: false, foreign_key: true, index: true

      t.string   :status, null: false, default: "in_progress"
      t.datetime :consultation_date, null: false
      t.integer  :duration_minutes

      # Clinical content
      t.string :chief_complaint          # motif in turboapp
      t.text   :observations
      t.text   :diagnosis                # diagnostic in turboapp
      t.text   :teeth_concerned, array: true, default: []
      t.jsonb  :procedures_performed,   null: false, default: [] # actes_realises
      t.jsonb  :dental_chart_snapshot,  null: false, default: {} # snapshot at completion
      t.text   :notes

      # Timestamps for state transitions
      t.datetime :completed_at
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :consultations, :status
    add_index :consultations, :consultation_date
    add_index :consultations, [ :organization_id, :consultation_date ]
  end
end
