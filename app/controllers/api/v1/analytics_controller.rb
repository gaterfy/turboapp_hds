# frozen_string_literal: true

module Api
  module V1
    # Agrégats type « tableau de bord cabinet » — même forme de payload que
    # GET /api/v1/logosw/analytics/dashboard sur turboapp (données HDS).
    class AnalyticsController < Api::V1::BaseController
      # GET /api/v1/analytics/dashboard
      def dashboard
        authorize current_organization, :analytics_dashboard?

        today = Date.current
        month_start = today.beginning_of_month
        org = current_organization

        patients = org.patients
        total_patients = patients.count
        active_patients = patients.active.count
        new_this_month = patients.where("created_at >= ?", month_start).count

        today_appointments = Appointment.where(organization_id: org.id)
                                        .where(start_time: today.all_day)
        today_appointments_data = today_appointments.includes(:patient, :practitioner)
                                                    .order(:start_time)
                                                    .map { |a| appointment_payload(a) }

        quotes_scope = Quote.where(organization_id: org.id)
        month_signed = quotes_scope.where(status: "signed")
                                   .where(signed_at: month_start.beginning_of_day..Time.zone.now.end_of_day)
        today_signed = quotes_scope.where(status: "signed")
                                   .where(signed_at: today.all_day)
        pending_quotes = quotes_scope.pending_signature
        signed_all = quotes_scope.where(status: "signed")
        total_quotes = quotes_scope.where.not(status: %w[rejected expired]).count
        acceptance_rate = total_quotes.positive? ? (signed_all.count.to_f / total_quotes * 100).round(1) : 0

        ca_today = today_signed.sum(:total_fees)
        ca_month = month_signed.sum(:total_fees)
        paid_month = month_signed.sum(:total_fees)
        outstanding = quotes_scope.where(status: "sent").sum(:total_patient_share)

        age_groups = patients.active.to_a
                             .group_by { |p| age_group_label(p.age) }
                             .transform_values(&:count)

        render_success(
          {
            today: today.iso8601,
            patients: {
              total: total_patients,
              active: active_patients,
              new_this_month: new_this_month,
              age_groups: age_groups
            },
            appointments_today: today_appointments_data,
            appointments_today_count: today_appointments.count,
            appointments_today_completed: today_appointments.where(status: "completed").count,
            revenue: {
              ca_today: ca_today.to_f,
              ca_month: ca_month.to_f,
              paid_month: paid_month.to_f,
              outstanding: outstanding.to_f
            },
            quotes: {
              pending_count: pending_quotes.count,
              pending_amount: pending_quotes.sum(:total_fees).to_f,
              signed_count: signed_all.count,
              signed_amount: signed_all.sum(:total_fees).to_f,
              acceptance_rate: acceptance_rate,
              recent: quotes_scope.order(created_at: :desc).limit(5)
                                  .includes(:line_items, patient_record: :patient)
                                  .map { |q| quote_payload(q) }
            },
            practitioners: org.practitioners.active.map { |p|
              { id: p.id, name: p.full_name, role: p.clinical_role }
            }
          }
        )
      rescue StandardError => e
        Rails.logger.error("[Analytics::Dashboard] #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        render_success(fallback_dashboard_payload)
      end

      private

      def appointment_payload(a)
        {
          id: a.id,
          start_time: a.start_time,
          end_time: a.end_time,
          status: a.status,
          reason: a.reason,
          appointment_type: a.appointment_type,
          patient_name: a.patient.full_name,
          patient_id: a.patient_id,
          practitioner_name: a.practitioner&.full_name,
          practitioner_id: a.practitioner_id
        }
      end

      def quote_payload(q)
        {
          id: q.id,
          devis_number: q.quote_number,
          patient_name: q.patient_record.patient.full_name,
          status: q.status,
          total_honoraires: q.total_fees.to_f,
          total_reste_a_charge: q.total_patient_share.to_f,
          created_at: q.created_at,
          nombre_actes: q.line_items.count
        }
      end

      def age_group_label(age)
        return "Inconnu" if age.nil?

        case age
        when 0..17 then "0-17"
        when 18..30 then "18-30"
        when 31..50 then "31-50"
        when 51..70 then "51-70"
        else "70+"
        end
      end

      def fallback_dashboard_payload
        {
          today: Date.current.iso8601,
          patients: { total: 0, active: 0, new_this_month: 0, age_groups: {} },
          appointments_today: [],
          appointments_today_count: 0,
          appointments_today_completed: 0,
          revenue: { ca_today: 0, ca_month: 0, paid_month: 0, outstanding: 0 },
          quotes: {
            pending_count: 0,
            pending_amount: 0,
            signed_count: 0,
            signed_amount: 0,
            acceptance_rate: 0,
            recent: []
          },
          practitioners: []
        }
      end
    end
  end
end
