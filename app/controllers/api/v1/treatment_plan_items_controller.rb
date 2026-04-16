# frozen_string_literal: true

module Api
  module V1
    class TreatmentPlanItemsController < Api::V1::BaseController
      before_action :set_plan
      before_action :set_item, only: %i[update destroy]

      def create
        authorize @plan, :manage_items?
        item = @plan.items.new(item_params)

        item.save!
        audit "created", resource: item
        render_success item.as_api_json, status: :created
      end

      def update
        authorize @plan, :manage_items?
        @item.update!(item_params)
        audit "updated", resource: @item
        render_success @item.as_api_json
      end

      def destroy
        authorize @plan, :manage_items?
        @item.destroy!
        audit "deleted", resource: @item
        head :no_content
      end

      private

      def set_plan
        @plan = policy_scope(TreatmentPlan).find(params[:treatment_plan_id])
      end

      def set_item
        @item = @plan.items.find(params[:id])
      end

      def item_params
        params.require(:item).permit(
          :procedure_code, :label, :tooth_ref, :quantity, :unit_fee, :position, :notes, :completed
        )
      end
    end
  end
end
