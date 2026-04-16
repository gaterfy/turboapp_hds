# frozen_string_literal: true

module Api
  module V1
    class TreatmentPlansController < Api::V1::BaseController
      before_action :set_plan, only: %i[show update accept start complete cancel]

      def index
        plans = policy_scope(TreatmentPlan)
                .includes(:practitioner, items: [])
                .then { |s| filter_by_record(s) }
                .then { |s| filter_by_status(s) }
                .order(created_at: :desc)
                .page(params[:page]).per(params[:per_page] || 25)

        authorize TreatmentPlan
        render_success plans_payload(plans)
      end

      def show
        authorize @plan
        audit "read", resource: @plan
        render_success plan_detail(@plan)
      end

      def create
        record = policy_scope(PatientRecord).find(params[:patient_record_id])
        plan = TreatmentPlan.new(plan_params.merge(
          patient_record: record,
          organization:   current_organization,
          practitioner:   current_practitioner!
        ))
        authorize plan

        plan.save!
        audit "created", resource: plan
        render_success plan.as_api_json, status: :created
      end

      def update
        authorize @plan
        @plan.update!(plan_params)
        audit "updated", resource: @plan, metadata: { changed: @plan.previous_changes.keys }
        render_success @plan.as_api_json
      end

      def accept
        authorize @plan, :accept?
        @plan.accept!
        audit "status_changed", resource: @plan, metadata: { new_status: "accepted" }
        render_success @plan.as_api_json
      end

      def start
        authorize @plan, :start?
        @plan.start!
        audit "status_changed", resource: @plan, metadata: { new_status: "started" }
        render_success @plan.as_api_json
      end

      def complete
        authorize @plan, :complete?
        @plan.complete!
        audit "status_changed", resource: @plan, metadata: { new_status: "completed" }
        render_success @plan.as_api_json
      end

      def cancel
        authorize @plan, :cancel?
        @plan.cancel!
        audit "status_changed", resource: @plan, metadata: { new_status: "cancelled" }
        render_success @plan.as_api_json
      end

      private

      def set_plan
        @plan = policy_scope(TreatmentPlan).find(params[:id])
      end

      def plan_params
        params.require(:treatment_plan).permit(
          :title, :description, :session_count, :estimated_total
        )
      end

      def filter_by_record(scope)
        params[:patient_record_id].present? ? scope.where(patient_record_id: params[:patient_record_id]) : scope
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def current_practitioner!
        Practitioner.find_by!(account: current_account, organization: current_organization)
      end

      def plan_detail(plan)
        plan.as_api_json.merge(items: plan.items.map(&:as_api_json))
      end

      def plans_payload(plans)
        {
          "treatment_plans" => plans.map(&:as_api_json),
          "meta" => {
            "current_page" => plans.current_page,
            "total_pages"  => plans.total_pages,
            "total_count"  => plans.total_count
          }
        }
      end
    end
  end
end
