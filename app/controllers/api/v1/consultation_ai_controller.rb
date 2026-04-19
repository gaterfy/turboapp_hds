# frozen_string_literal: true

module Api
  module V1
    # IA consultation — aligné sur turboapp Logosw::ConsultationAiController,
    # sous garde JWT HDS + MFA + X-Organization-Id (Api::V1::BaseController).
    class ConsultationAiController < Api::V1::BaseController
      # POST /api/v1/consultation_ai/generate_report
      def generate_report
        authorize Consultation, :generate_ai_report?

        transcript_lines = params[:transcript_lines]
        patient_name = params[:patient_name]
        colleague_kind = params[:colleague_kind] || "prosthetist"

        unless transcript_lines.is_a?(Array) && transcript_lines.any?(&:present?)
          return render_error("validation_failed", "transcript_lines requis (tableau non vide)",
                              status: :unprocessable_entity)
        end

        if patient_name.blank?
          return render_error("validation_failed", "patient_name requis", status: :unprocessable_entity)
        end

        service = ::Logosw::ConsultationAi::GenerateReportService.new
        result = service.call(
          transcript_lines: transcript_lines,
          patient_name: patient_name,
          colleague_kind: colleague_kind
        )

        audit "consultation_ai_generate_report",
              metadata: { lines: transcript_lines.size }
        render_success result
      end

      # POST /api/v1/consultation_ai/generate_colleague_letter
      def generate_colleague_letter
        authorize Consultation, :generate_ai_colleague_letter?

        transcript_lines = params[:transcript_lines]
        patient_name = params[:patient_name]
        colleague_kind = params[:colleague_kind]

        unless transcript_lines.is_a?(Array) && transcript_lines.any?(&:present?)
          return render_error("validation_failed", "transcript_lines requis", status: :unprocessable_entity)
        end

        service = ::Logosw::ConsultationAi::GenerateReportService.new
        result = service.generate_colleague_letter(
          transcript_lines: transcript_lines,
          patient_name: patient_name.presence || "Patient",
          colleague_kind: colleague_kind || "other"
        )

        audit "consultation_ai_generate_colleague_letter",
              metadata: { lines: transcript_lines.size }
        render_success result
      end

      # POST /api/v1/consultation_ai/patient_report_pdf
      def patient_report_pdf
        authorize Consultation, :export_ai_patient_report_pdf?

        patient_name = params[:patient_name].to_s
        report = params[:patient_report].to_s

        if patient_name.blank?
          return render_error("validation_failed", "patient_name requis", status: :unprocessable_entity)
        end
        if report.blank?
          return render_error("validation_failed", "patient_report requis", status: :unprocessable_entity)
        end

        cabinet = current_organization.name
        practitioner = Practitioner.find_by(account: current_account, organization: current_organization)&.full_name
        practitioner = current_account.email if practitioner.blank?

        pdf_bytes = ::Logosw::ConsultationAi::PatientReportPdf.new(
          patient_name: patient_name,
          report_markdown: report,
          cabinet_label: cabinet,
          practitioner_name: practitioner
        ).render

        audit "consultation_ai_patient_report_pdf",
              metadata: { patient_name: patient_name.truncate(80) }

        filename = "compte-rendu-#{patient_name.parameterize.presence || 'patient'}-#{Time.zone.today}.pdf"
        send_data pdf_bytes, filename: filename, type: "application/pdf", disposition: "attachment"
      end
    end
  end
end
