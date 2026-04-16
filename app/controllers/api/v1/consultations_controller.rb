# frozen_string_literal: true

module Api
  module V1
    class ConsultationsController < Api::V1::BaseController
      before_action :set_consultation, only: %i[show update complete seal ai_report]

      def index
        consultations = policy_scope(Consultation)
                        .includes(:practitioner, :appointment)
                        .then { |s| filter_by_patient_record(s) }
                        .then { |s| filter_by_status(s) }
                        .recent
                        .page(params[:page]).per(params[:per_page] || 25)

        authorize Consultation
        render_success consultations_payload(consultations)
      end

      def show
        authorize @consultation
        audit "read", resource: @consultation
        render_success @consultation.as_api_json
      end

      def create
        patient_record = policy_scope(PatientRecord).find(params[:patient_record_id])
        consultation = Consultation.new(consultation_params.merge(
          patient_record: patient_record,
          organization: current_organization,
          practitioner: current_practitioner!
        ))
        authorize consultation

        consultation.save!
        audit "created", resource: consultation
        render_success consultation.as_api_json, status: :created
      end

      def update
        authorize @consultation
        @consultation.update!(consultation_params)

        audit "updated", resource: @consultation, metadata: { changed: @consultation.previous_changes.keys }
        render_success @consultation.as_api_json
      end

      def complete
        authorize @consultation, :complete?
        chart_snapshot = params[:dental_chart_snapshot]

        @consultation.complete!(chart_snapshot: chart_snapshot)
        audit "status_changed", resource: @consultation, metadata: { new_status: "completed" }
        render_success @consultation.as_api_json
      end

      def ai_report
        authorize @consultation, :show?

        patient_name = @consultation.patient_record.patient.then do |p|
          "#{p.first_name} #{p.last_name}"
        end

        transcript_lines = Array(params[:transcript_lines])
        colleague_kind   = params[:colleague_kind].presence || "referring_dentist"

        result = ClinicalAi::ConsultationReportService.new.call(
          transcript_lines: transcript_lines,
          patient_name:     patient_name,
          colleague_kind:   colleague_kind
        )

        @consultation.update!(
          ai_generated_report:  result[:patient_report],
          ai_colleague_letter:  { subject: result[:colleague_subject], body: result[:colleague_body] },
          ai_generated_at:      Time.current,
          ai_model_used:        result[:model_used]
        )

        audit "ai_report_generated", resource: @consultation,
              metadata: { model: result[:model_used], colleague_kind: colleague_kind }

        render_success result
      end

      def seal
        authorize @consultation, :seal?
        @consultation.seal!

        audit "status_changed", resource: @consultation, metadata: { new_status: "locked" }
        render_success @consultation.as_api_json
      end

      private

      def set_consultation
        @consultation = policy_scope(Consultation).find(params[:id])
      end

      def consultation_params
        params.require(:consultation).permit(
          :appointment_id, :consultation_date, :duration_minutes,
          :chief_complaint, :observations, :diagnosis, :notes,
          teeth_concerned: [],
          procedures_performed: {},
          dental_chart_snapshot: {}
        )
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

      def consultations_payload(consultations)
        {
          consultations: consultations.map(&:as_api_json),
          meta: {
            current_page: consultations.current_page,
            total_pages:  consultations.total_pages,
            total_count:  consultations.total_count
          }
        }
      end
    end
  end
end
