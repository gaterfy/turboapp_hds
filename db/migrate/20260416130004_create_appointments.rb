# frozen_string_literal: true

# Appointment = scheduling intent.
# Separate from Consultation (clinical event): an appointment can exist
# without a consultation (cancelled, no-show) and a consultation can
# exist without a prior appointment (emergency).
class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :organization,  null: false, foreign_key: true, index: true
      t.references :patient,       null: false, foreign_key: true, index: true
      t.references :practitioner,  null: false, foreign_key: true, index: true

      t.string   :room_id
      t.datetime :start_time, null: false
      t.datetime :end_time,   null: false

      t.string  :appointment_type
      t.string  :status, null: false, default: "scheduled"

      t.text    :reason
      t.text    :notes

      t.boolean :is_online,           null: false, default: false
      t.boolean :is_teleconsultation, null: false, default: false
      t.string  :teleconsultation_link

      t.jsonb   :reminder
      t.datetime :reminder_sent_at

      t.string  :cancel_reason
      t.datetime :cancelled_at

      t.timestamps null: false
    end

    add_index :appointments, :start_time
    add_index :appointments, :status
    add_index :appointments, [ :organization_id, :practitioner_id, :start_time ],
              name: "idx_appointments_org_practitioner_time"
  end
end
