# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_16_160001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "account_type", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "jti_secret", default: -> { "gen_random_uuid()" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mfa_secret"
    t.boolean "mfa_enabled", default: false, null: false
    t.datetime "mfa_enabled_at"
    t.text "mfa_backup_codes", default: [], array: true
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["active"], name: "index_accounts_on_active"
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.index ["jti_secret"], name: "index_accounts_on_jti_secret", unique: true
    t.index ["mfa_enabled"], name: "index_accounts_on_mfa_enabled"
    t.index ["reset_password_token"], name: "index_accounts_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_accounts_on_unlock_token", unique: true
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "patient_id", null: false
    t.bigint "practitioner_id", null: false
    t.string "room_id"
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "appointment_type"
    t.string "status", default: "scheduled", null: false
    t.text "reason"
    t.text "notes"
    t.boolean "is_online", default: false, null: false
    t.boolean "is_teleconsultation", default: false, null: false
    t.string "teleconsultation_link"
    t.jsonb "reminder"
    t.datetime "reminder_sent_at"
    t.string "cancel_reason"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "practitioner_id", "start_time"], name: "idx_appointments_org_practitioner_time"
    t.index ["organization_id"], name: "index_appointments_on_organization_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.index ["practitioner_id"], name: "index_appointments_on_practitioner_id"
    t.index ["start_time"], name: "index_appointments_on_start_time"
    t.index ["status"], name: "index_appointments_on_status"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "organization_id"
    t.string "action", null: false
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.index ["account_id"], name: "index_audit_logs_on_account_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
  end

  create_table "consultations", force: :cascade do |t|
    t.bigint "patient_record_id", null: false
    t.bigint "practitioner_id", null: false
    t.bigint "appointment_id"
    t.bigint "organization_id", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "consultation_date", null: false
    t.integer "duration_minutes"
    t.string "chief_complaint"
    t.text "observations"
    t.text "diagnosis"
    t.text "teeth_concerned", default: [], array: true
    t.jsonb "procedures_performed", default: [], null: false
    t.jsonb "dental_chart_snapshot", default: {}, null: false
    t.text "notes"
    t.datetime "completed_at"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "ai_generated_report"
    t.jsonb "ai_colleague_letter", default: {}
    t.datetime "ai_generated_at"
    t.string "ai_model_used"
    t.index ["appointment_id"], name: "index_consultations_on_appointment_id"
    t.index ["consultation_date"], name: "index_consultations_on_consultation_date"
    t.index ["organization_id", "consultation_date"], name: "index_consultations_on_organization_id_and_consultation_date"
    t.index ["organization_id"], name: "index_consultations_on_organization_id"
    t.index ["patient_record_id"], name: "index_consultations_on_patient_record_id"
    t.index ["practitioner_id"], name: "index_consultations_on_practitioner_id"
    t.index ["status"], name: "index_consultations_on_status"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylist_on_exp"
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "organization_id", null: false
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "joined_at", default: -> { "now()" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "organization_id"], name: "index_memberships_on_account_id_and_organization_id", unique: true
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["active"], name: "index_memberships_on_active"
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_organizations_on_active"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "patient_records", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "primary_practitioner_id"
    t.string "status", default: "active", null: false
    t.text "allergies", default: [], array: true
    t.text "chronic_diseases", default: [], array: true
    t.text "medications", default: [], array: true
    t.string "blood_type"
    t.text "medical_notes"
    t.jsonb "dental_chart", default: {}, null: false
    t.decimal "ai_health_score", precision: 5, scale: 2
    t.datetime "opened_at", default: -> { "now()" }, null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_patient_records_on_organization_id"
    t.index ["patient_id", "organization_id"], name: "idx_unique_patient_record_per_org", unique: true
    t.index ["patient_id"], name: "index_patient_records_on_patient_id"
    t.index ["primary_practitioner_id"], name: "index_patient_records_on_primary_practitioner_id"
    t.index ["status"], name: "index_patient_records_on_status"
  end

  create_table "patients", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "account_id"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "mobile"
    t.date "birth_date", null: false
    t.string "gender"
    t.string "address"
    t.string "city"
    t.string "postal_code"
    t.string "country"
    t.string "social_security_number"
    t.string "insurance_provider"
    t.string "insurance_number"
    t.string "emergency_contact"
    t.string "emergency_phone"
    t.text "notes"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_patients_on_account_id"
    t.index ["organization_id", "email"], name: "idx_patients_org_email_unique", unique: true
    t.index ["organization_id", "email"], name: "index_patients_on_organization_id_and_email"
    t.index ["organization_id"], name: "index_patients_on_organization_id"
    t.index ["status"], name: "index_patients_on_status"
  end

  create_table "practitioners", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "account_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "specialization", null: false
    t.string "license_number", null: false
    t.string "clinical_role", default: "dentist", null: false
    t.string "status", default: "active", null: false
    t.string "avatar"
    t.jsonb "working_hours", default: [], null: false
    t.text "skills", default: [], array: true
    t.decimal "rating", precision: 3, scale: 2
    t.integer "total_reviews", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_practitioners_on_account_id"
    t.index ["clinical_role"], name: "index_practitioners_on_clinical_role"
    t.index ["email"], name: "index_practitioners_on_email"
    t.index ["license_number", "organization_id"], name: "index_practitioners_on_license_number_and_organization_id", unique: true
    t.index ["organization_id"], name: "index_practitioners_on_organization_id"
    t.index ["status"], name: "index_practitioners_on_status"
  end

  create_table "prescription_line_items", force: :cascade do |t|
    t.bigint "prescription_id", null: false
    t.string "medication", null: false
    t.string "dosage", null: false
    t.string "duration"
    t.integer "quantity", default: 1, null: false
    t.boolean "renewable", default: false, null: false
    t.integer "position", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prescription_id", "position"], name: "index_prescription_line_items_on_prescription_id_and_position"
    t.index ["prescription_id"], name: "index_prescription_line_items_on_prescription_id"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.bigint "patient_record_id", null: false
    t.bigint "practitioner_id", null: false
    t.bigint "consultation_id"
    t.bigint "organization_id", null: false
    t.string "prescription_number", null: false
    t.date "prescription_date", null: false
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.string "signature_submission_id"
    t.datetime "signed_at"
    t.datetime "delivered_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consultation_id"], name: "index_prescriptions_on_consultation_id"
    t.index ["organization_id"], name: "index_prescriptions_on_organization_id"
    t.index ["patient_record_id"], name: "index_prescriptions_on_patient_record_id"
    t.index ["practitioner_id"], name: "index_prescriptions_on_practitioner_id"
    t.index ["prescription_date"], name: "index_prescriptions_on_prescription_date"
    t.index ["prescription_number"], name: "index_prescriptions_on_prescription_number", unique: true
    t.index ["status"], name: "index_prescriptions_on_status"
  end

  create_table "quote_line_items", force: :cascade do |t|
    t.bigint "quote_id", null: false
    t.string "procedure_code"
    t.string "label", null: false
    t.string "tooth_location"
    t.integer "quantity", default: 1, null: false
    t.integer "position", default: 0, null: false
    t.decimal "unit_fee", precision: 10, scale: 2, null: false
    t.decimal "reimbursement_base", precision: 10, scale: 2, default: "0.0"
    t.decimal "reimbursement_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "reimbursement_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "patient_share", precision: 10, scale: 2, default: "0.0"
    t.decimal "overage", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id", "position"], name: "index_quote_line_items_on_quote_id_and_position"
    t.index ["quote_id"], name: "index_quote_line_items_on_quote_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.bigint "patient_record_id", null: false
    t.bigint "practitioner_id", null: false
    t.bigint "organization_id", null: false
    t.string "quote_number", null: false
    t.string "status", default: "draft", null: false
    t.date "valid_until"
    t.decimal "total_fees", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_reimbursement_base", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_patient_share", precision: 10, scale: 2, default: "0.0"
    t.text "notes"
    t.string "signature_submission_id"
    t.datetime "sent_at"
    t.datetime "signed_at"
    t.datetime "rejected_at"
    t.datetime "expired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "treatment_plan_id"
    t.index ["organization_id"], name: "index_quotes_on_organization_id"
    t.index ["patient_record_id"], name: "index_quotes_on_patient_record_id"
    t.index ["practitioner_id"], name: "index_quotes_on_practitioner_id"
    t.index ["quote_number"], name: "index_quotes_on_quote_number", unique: true
    t.index ["signature_submission_id"], name: "index_quotes_on_signature_submission_id"
    t.index ["status"], name: "index_quotes_on_status"
    t.index ["treatment_plan_id"], name: "index_quotes_on_treatment_plan_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "revoked_reason"
    t.string "issued_ip"
    t.string "issued_user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_refresh_tokens_on_account_id"
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["revoked_at"], name: "index_refresh_tokens_on_revoked_at"
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "treatment_plan_items", force: :cascade do |t|
    t.bigint "treatment_plan_id", null: false
    t.string "procedure_code"
    t.string "label", null: false
    t.string "tooth_ref"
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_fee", precision: 10, scale: 2, null: false
    t.integer "position", default: 0, null: false
    t.text "notes"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_treatment_plan_items_on_position"
    t.index ["treatment_plan_id"], name: "index_treatment_plan_items_on_treatment_plan_id"
  end

  create_table "treatment_plans", force: :cascade do |t|
    t.bigint "patient_record_id", null: false
    t.bigint "practitioner_id", null: false
    t.bigint "organization_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "proposed", null: false
    t.integer "session_count"
    t.decimal "estimated_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "accepted_total", precision: 10, scale: 2
    t.datetime "accepted_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_treatment_plans_on_organization_id"
    t.index ["patient_record_id"], name: "index_treatment_plans_on_patient_record_id"
    t.index ["practitioner_id"], name: "index_treatment_plans_on_practitioner_id"
    t.index ["status"], name: "index_treatment_plans_on_status"
  end

  add_foreign_key "appointments", "organizations"
  add_foreign_key "appointments", "patients"
  add_foreign_key "appointments", "practitioners"
  add_foreign_key "consultations", "appointments"
  add_foreign_key "consultations", "organizations"
  add_foreign_key "consultations", "patient_records"
  add_foreign_key "consultations", "practitioners"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "patient_records", "organizations"
  add_foreign_key "patient_records", "patients"
  add_foreign_key "patient_records", "practitioners", column: "primary_practitioner_id"
  add_foreign_key "patients", "accounts"
  add_foreign_key "patients", "organizations"
  add_foreign_key "practitioners", "accounts"
  add_foreign_key "practitioners", "organizations"
  add_foreign_key "prescription_line_items", "prescriptions"
  add_foreign_key "prescriptions", "consultations"
  add_foreign_key "prescriptions", "organizations"
  add_foreign_key "prescriptions", "patient_records"
  add_foreign_key "prescriptions", "practitioners"
  add_foreign_key "quote_line_items", "quotes"
  add_foreign_key "quotes", "organizations"
  add_foreign_key "quotes", "patient_records"
  add_foreign_key "quotes", "practitioners"
  add_foreign_key "quotes", "treatment_plans"
  add_foreign_key "refresh_tokens", "accounts"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "treatment_plan_items", "treatment_plans"
  add_foreign_key "treatment_plans", "organizations"
  add_foreign_key "treatment_plans", "patient_records"
  add_foreign_key "treatment_plans", "practitioners"
end
