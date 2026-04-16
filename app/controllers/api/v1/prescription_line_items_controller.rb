# frozen_string_literal: true

module Api
  module V1
    # Nested under prescriptions: /api/v1/prescriptions/:prescription_id/line_items
    class PrescriptionLineItemsController < Api::V1::BaseController
      before_action :set_prescription
      before_action :set_line_item, only: %i[update destroy]

      def create
        authorize @prescription, :manage_line_items?
        line_item = @prescription.line_items.build(line_item_params)

        line_item.save!
        audit "created", resource: line_item, metadata: { prescription_id: @prescription.id }
        render_success line_item.as_api_json, status: :created
      end

      def update
        authorize @prescription, :manage_line_items?
        @line_item.update!(line_item_params)

        audit "updated", resource: @line_item, metadata: { changed: @line_item.previous_changes.keys }
        render_success @line_item.as_api_json
      end

      def destroy
        authorize @prescription, :manage_line_items?
        @line_item.destroy!

        audit "deleted", resource: @line_item
        head :no_content
      end

      private

      def set_prescription
        @prescription = policy_scope(Prescription).find(params[:prescription_id])
      end

      def set_line_item
        @line_item = @prescription.line_items.find(params[:id])
      end

      def line_item_params
        params.require(:prescription_line_item).permit(
          :medication, :dosage, :duration, :quantity, :renewable, :position, :notes
        )
      end
    end
  end
end
