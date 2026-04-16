# frozen_string_literal: true

module Api
  module V1
    class PractitionersController < Api::V1::BaseController
      before_action :set_practitioner, only: %i[show update deactivate]

      def index
        practitioners = policy_scope(Practitioner).order(:last_name, :first_name)
        authorize Practitioner
        render_success practitioners.map(&:as_api_json)
      end

      def show
        authorize @practitioner
        audit "read", resource: @practitioner
        render_success @practitioner.as_api_json
      end

      def create
        practitioner = current_organization.practitioners.build(practitioner_params)
        authorize practitioner

        practitioner.save!
        audit "created", resource: practitioner
        render_success practitioner.as_api_json, status: :created
      end

      def update
        authorize @practitioner
        @practitioner.update!(practitioner_params)

        audit "updated", resource: @practitioner, metadata: { changed: @practitioner.previous_changes.keys }
        render_success @practitioner.as_api_json
      end

      def deactivate
        authorize @practitioner, :deactivate?
        @practitioner.update!(status: "inactive")

        audit "status_changed", resource: @practitioner, metadata: { new_status: "inactive" }
        render_success @practitioner.as_api_json
      end

      private

      def set_practitioner
        @practitioner = policy_scope(Practitioner).find(params[:id])
      end

      def practitioner_params
        params.require(:practitioner).permit(
          :first_name, :last_name, :email, :phone,
          :specialization, :license_number, :clinical_role, :status,
          :avatar, :rating,
          working_hours: {}, skills: []
        )
      end
    end
  end
end
