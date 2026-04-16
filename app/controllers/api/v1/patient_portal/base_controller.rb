# frozen_string_literal: true

module Api
  module V1
    module PatientPortal
      # Base controller for patient-facing endpoints.
      #
      # Security invariants:
      #   1. Account must be authenticated (valid JWT).
      #   2. Account must be of type :patient.
      #   3. All data returned is scoped to the patient's own records.
      #   4. The X-Organization-Id header is still required so the patient
      #      accesses the right cabinet's data.
      class BaseController < Api::V1::BaseController
        before_action :require_patient_account!

        private

        def require_patient_account!
          return if current_account&.patient?

          skip_authorization_and_scope
          render_error "forbidden", "This endpoint is only accessible to patient accounts", status: :forbidden
        end

        # The patient linked to this account within the current organization.
        def current_patient
          @current_patient ||= Patient.find_by!(
            account:      current_account,
            organization: current_organization
          )
        rescue ActiveRecord::RecordNotFound
          skip_authorization_and_scope
          render_error "patient_not_found",
                       "No patient profile found for this account in this organization",
                       status: :not_found
        end
      end
    end
  end
end
