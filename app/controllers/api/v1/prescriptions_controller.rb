# frozen_string_literal: true

module Api
  module V1
    class PrescriptionsController < Api::V1::BaseController
      before_action :set_prescription, only: %i[show update sign deliver cancel]

      def index
        prescriptions = policy_scope(Prescription)
                        .includes(:line_items, :practitioner)
                        .then { |s| filter_by_patient_record(s) }
                        .then { |s| filter_by_status(s) }
                        .order(prescription_date: :desc)
                        .page(params[:page]).per(params[:per_page] || 25)

        authorize Prescription
        render_success prescriptions_payload(prescriptions)
      end

      def show
        authorize @prescription
        audit "read", resource: @prescription
        render_success @prescription.as_api_json
      end

      def create
        patient_record = policy_scope(PatientRecord).find(params[:patient_record_id])
        prescription = Prescription.new(prescription_params.merge(
          patient_record: patient_record,
          organization: current_organization,
          practitioner: current_practitioner!,
          prescription_date: Date.current
        ))
        authorize prescription

        prescription.save!
        audit "created", resource: prescription
        render_success prescription.as_api_json, status: :created
      end

      def update
        authorize @prescription
        @prescription.update!(prescription_params)

        audit "updated", resource: @prescription, metadata: { changed: @prescription.previous_changes.keys }
        render_success @prescription.as_api_json
      end

      def sign
        authorize @prescription, :sign?
        @prescription.sign!

        audit "status_changed", resource: @prescription, metadata: { new_status: "signed" }
        render_success @prescription.as_api_json
      end

      def deliver
        authorize @prescription, :deliver?
        @prescription.deliver!

        audit "status_changed", resource: @prescription, metadata: { new_status: "delivered" }
        render_success @prescription.as_api_json
      end

      def cancel
        authorize @prescription, :cancel?
        @prescription.cancel!

        audit "status_changed", resource: @prescription, metadata: { new_status: "cancelled" }
        render_success @prescription.as_api_json
      end

      private

      def set_prescription
        @prescription = policy_scope(Prescription).find(params[:id])
      end

      def prescription_params
        params.require(:prescription).permit(:consultation_id, :notes)
      end

      def filter_by_patient_record(scope)
        params[:patient_record_id].present? ? scope.where(patient_record_id: params[:patient_record_id]) : scope
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def current_practitioner!
        Practitioner.find_by!(account: current_account, organization: current_organization)
      rescue ActiveRecord::RecordNotFound
        raise ActiveRecord::RecordNotFound, "No practitioner profile found for this account in this organization"
      end

      def prescriptions_payload(prescriptions)
        {
          prescriptions: prescriptions.map(&:as_api_json),
          meta: {
            current_page: prescriptions.current_page,
            total_pages:  prescriptions.total_pages,
            total_count:  prescriptions.total_count
          }
        }
      end
    end
  end
end
