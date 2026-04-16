# frozen_string_literal: true

module Api
  module V1
    class PatientsController < Api::V1::BaseController
      before_action :set_patient, only: %i[show update]

      def index
        patients = policy_scope(Patient)
                   .then { |s| filter_by_status(s) }
                   .then { |s| filter_by_search(s) }
                   .order(last_name: :asc, first_name: :asc)
                   .page(params[:page])
                   .per(params[:per_page] || 25)

        authorize Patient
        audit "read", resource: Patient, metadata: { count: patients.total_count, filters: filter_params }
        render_success patients_payload(patients)
      end

      def show
        authorize @patient
        audit "read", resource: @patient
        render_success @patient.as_api_json
      end

      def create
        patient = current_organization.patients.build(patient_params)
        authorize patient

        patient.save!
        PatientRecord.create!(patient: patient, organization: current_organization)

        audit "created", resource: patient
        render_success patient.as_api_json, status: :created
      end

      def update
        authorize @patient
        @patient.update!(patient_update_params)

        audit "updated", resource: @patient, metadata: { changed: @patient.previous_changes.keys }
        render_success @patient.as_api_json
      end

      private

      def set_patient
        @patient = policy_scope(Patient).find(params[:id])
      end

      def patient_params
        params.require(:patient).permit(
          :first_name, :last_name, :email, :phone, :mobile,
          :birth_date, :gender, :address, :city, :postal_code, :country,
          :insurance_provider, :insurance_number,
          :emergency_contact, :emergency_phone, :notes, :status
        )
      end

      # Assistants cannot update sensitive fields
      def patient_update_params
        allowed = patient_params
        if current_membership.assistant?
          allowed.except(:social_security_number, :insurance_number, :status)
        else
          allowed
        end
      end

      def filter_params
        params.slice(:status, :search)
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def filter_by_search(scope)
        params[:search].present? ? scope.search(params[:search]) : scope
      end

      def patients_payload(patients)
        {
          patients: patients.map(&:as_api_json),
          meta: {
            current_page: patients.current_page,
            total_pages: patients.total_pages,
            total_count: patients.total_count
          }
        }
      end
    end
  end
end
