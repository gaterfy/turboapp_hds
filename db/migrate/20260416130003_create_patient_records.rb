# frozen_string_literal: true

# Aggregate root of the clinical domain.
# All clinical documents (consultations, quotes, prescriptions)
# attach to the PatientRecord, never directly to the Patient.
# One record per patient per organization – enforced by the unique index.
class CreatePatientRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :patient_records do |t|
      t.references :patient,      null: false, foreign_key: true, index: true
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :primary_practitioner, null: true,
                   foreign_key: { to_table: :practitioners }, index: true

      t.string  :status, null: false, default: "active"

      # Medical history – stored as PG arrays for efficient querying
      t.text    :allergies,        array: true, default: []
      t.text    :chronic_diseases, array: true, default: []
      t.text    :medications,      array: true, default: []
      t.string  :blood_type

      t.text    :medical_notes
      # Dental chart stored as a flexible JSON structure
      t.jsonb   :dental_chart, null: false, default: {}

      # AI-generated health score (future sprint)
      t.decimal :ai_health_score, precision: 5, scale: 2

      t.datetime :opened_at, null: false, default: -> { "NOW()" }
      t.datetime :closed_at

      t.timestamps null: false
    end

    add_index :patient_records, :status
    add_index :patient_records, [ :patient_id, :organization_id ], unique: true,
              name: "idx_unique_patient_record_per_org"
  end
end
