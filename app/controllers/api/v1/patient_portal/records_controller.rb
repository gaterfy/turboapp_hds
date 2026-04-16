# frozen_string_literal: true

module Api
  module V1
    module PatientPortal
      # GET /api/v1/patient_portal/record  (singular – one record per org)
      # GET /api/v1/patient_portal/record/appointments
      # GET /api/v1/patient_portal/record/consultations
      # GET /api/v1/patient_portal/record/quotes
      # GET /api/v1/patient_portal/record/prescriptions
      # GET /api/v1/patient_portal/record/treatment_plans
      class RecordsController < PatientPortal::BaseController
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        def show
          record = own_record
          audit "patient_portal_read", resource: record, metadata: { section: "record" }
          render_success record.as_api_json
        end

        def appointments
          appts = Appointment.where(patient: own_record.patient, organization: current_organization)
                             .order(start_time: :desc)
                             .page(params[:page]).per(25)

          audit "patient_portal_read", resource: own_record, metadata: { section: "appointments" }
          render_success({
            appointments: appts.map(&:as_api_json),
            meta: paginate_meta(appts)
          })
        end

        def consultations
          records = own_record.consultations
                              .where.not(status: "in_progress")
                              .recent
                              .page(params[:page]).per(25)

          audit "patient_portal_read", resource: own_record, metadata: { section: "consultations" }
          render_success({
            consultations: records.map(&:as_api_json),
            meta: paginate_meta(records)
          })
        end

        def quotes
          qs = own_record.quotes
                         .where.not(status: "draft")
                         .order(created_at: :desc)
                         .page(params[:page]).per(25)

          audit "patient_portal_read", resource: own_record, metadata: { section: "quotes" }
          render_success({ quotes: qs.map(&:as_api_json), meta: paginate_meta(qs) })
        end

        def prescriptions
          rxs = own_record.prescriptions
                          .where.not(status: "draft")
                          .order(created_at: :desc)
                          .page(params[:page]).per(25)

          audit "patient_portal_read", resource: own_record, metadata: { section: "prescriptions" }
          render_success({ prescriptions: rxs.map(&:as_api_json), meta: paginate_meta(rxs) })
        end

        def treatment_plans
          plans = own_record.treatment_plans
                            .where(status: %w[accepted started completed])
                            .order(created_at: :desc)
                            .page(params[:page]).per(25)

          audit "patient_portal_read", resource: own_record, metadata: { section: "treatment_plans" }
          render_success({ treatment_plans: plans.map(&:as_api_json), meta: paginate_meta(plans) })
        end

        private

        def own_record
          @own_record ||= PatientRecord.find_by!(
            patient:      current_patient,
            organization: current_organization
          )
        rescue ActiveRecord::RecordNotFound
          render_error "not_found", "No patient record found in this organization", status: :not_found
        end

        def paginate_meta(scope)
          { current_page: scope.current_page, total_pages: scope.total_pages, total_count: scope.total_count }
        end
      end
    end
  end
end
