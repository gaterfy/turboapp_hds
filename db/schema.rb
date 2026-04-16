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

ActiveRecord::Schema[8.0].define(version: 2026_04_16_130004) do
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
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["active"], name: "index_accounts_on_active"
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.index ["jti_secret"], name: "index_accounts_on_jti_secret", unique: true
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

  add_foreign_key "appointments", "organizations"
  add_foreign_key "appointments", "patients"
  add_foreign_key "appointments", "practitioners"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "patient_records", "organizations"
  add_foreign_key "patient_records", "patients"
  add_foreign_key "patient_records", "practitioners", column: "primary_practitioner_id"
  add_foreign_key "patients", "accounts"
  add_foreign_key "patients", "organizations"
  add_foreign_key "practitioners", "accounts"
  add_foreign_key "practitioners", "organizations"
  add_foreign_key "refresh_tokens", "accounts"
end
