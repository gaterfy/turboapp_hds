# frozen_string_literal: true

module Api
  module V1
    class AppointmentsController < Api::V1::BaseController
      before_action :set_appointment, only: %i[show update cancel]

      def index
        appointments = policy_scope(Appointment)
                       .includes(:patient, :practitioner)
                       .then { |s| filter_by_date(s) }
                       .then { |s| filter_by_practitioner(s) }
                       .then { |s| filter_by_status(s) }
                       .order(:start_time)
                       .page(params[:page])
                       .per(params[:per_page] || 50)

        authorize Appointment
        render_success appointments_payload(appointments)
      end

      def show
        authorize @appointment
        audit "read", resource: @appointment
        render_success @appointment.as_api_json
      end

      def create
        appointment = current_organization.appointments.build(appointment_params)
        authorize appointment

        appointment.save!
        audit "created", resource: appointment
        render_success appointment.as_api_json, status: :created
      end

      def update
        authorize @appointment
        @appointment.update!(appointment_params)

        audit "updated", resource: @appointment, metadata: { changed: @appointment.previous_changes.keys }
        render_success @appointment.as_api_json
      end

      def cancel
        authorize @appointment, :cancel?
        reason = params[:cancel_reason].presence || "No reason provided"

        @appointment.cancel!(reason: reason)
        audit "status_changed", resource: @appointment, metadata: { new_status: "cancelled", reason: reason }
        render_success @appointment.as_api_json
      end

      private

      def set_appointment
        @appointment = policy_scope(Appointment).find(params[:id])
      end

      def appointment_params
        params.require(:appointment).permit(
          :patient_id, :practitioner_id, :room_id,
          :start_time, :end_time, :appointment_type, :status,
          :reason, :notes,
          :is_online, :is_teleconsultation, :teleconsultation_link,
          reminder: {}
        )
      end

      def filter_by_date(scope)
        if params[:date].present?
          date = Date.parse(params[:date])
          scope.for_date(date)
        elsif params[:from].present? && params[:to].present?
          scope.where(start_time: Date.parse(params[:from])..Date.parse(params[:to]))
        else
          scope
        end
      rescue Date::Error
        scope
      end

      def filter_by_practitioner(scope)
        params[:practitioner_id].present? ? scope.where(practitioner_id: params[:practitioner_id]) : scope
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def appointments_payload(appointments)
        {
          appointments: appointments.map(&:as_api_json),
          meta: {
            current_page: appointments.current_page,
            total_pages: appointments.total_pages,
            total_count: appointments.total_count
          }
        }
      end
    end
  end
end
