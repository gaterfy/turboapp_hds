# frozen_string_literal: true

module Api
  module V1
    class PatientRecordsController < Api::V1::BaseController
      before_action :set_patient_record, only: %i[show update archive]

      def index
        records = policy_scope(PatientRecord).includes(:patient, :primary_practitioner)
        authorize PatientRecord
        audit "read", resource: PatientRecord, metadata: { count: records.count }
        render_success records.map(&:as_api_json)
      end

      def show
        authorize @record
        audit "read", resource: @record
        render_success @record.as_api_json
      end

      def create
        patient = policy_scope(Patient).find(params[:patient_id])
        record = PatientRecord.new(patient_record_params.merge(
          patient: patient,
          organization: current_organization
        ))
        authorize record

        record.save!
        audit "created", resource: record
        render_success record.as_api_json, status: :created
      end

      def update
        authorize @record
        @record.update!(patient_record_params)

        audit "updated", resource: @record, metadata: { changed: @record.previous_changes.keys }
        render_success @record.as_api_json
      end

      def archive
        authorize @record, :archive?
        @record.archive!

        audit "status_changed", resource: @record, metadata: { new_status: "archived" }
        render_success @record.as_api_json
      end

      # GET /api/v1/dossier_patients/by_patient/:patient_id — alias turboapp Logosw
      def by_patient
        record = policy_scope(PatientRecord).find_by!(patient_id: params[:patient_id])
        authorize record, :by_patient?

        audit "read", resource: record, metadata: { by_patient_id: params[:patient_id] }
        render_success record.as_api_json
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "No clinical record for this patient in this organization",
                     status: :not_found)
      end

      private

      def set_patient_record
        @record = policy_scope(PatientRecord).find(params[:id])
      end

      def patient_record_params
        params.require(:patient_record).permit(
          :primary_practitioner_id, :blood_type, :medical_notes,
          :status,
          allergies: [], chronic_diseases: [], medications: [],
          dental_chart: {}
        )
      end
    end
  end
end
