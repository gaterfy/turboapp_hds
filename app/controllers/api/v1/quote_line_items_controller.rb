# frozen_string_literal: true

module Api
  module V1
    # Nested under quotes: /api/v1/quotes/:quote_id/line_items
    class QuoteLineItemsController < Api::V1::BaseController
      before_action :set_quote
      before_action :set_line_item, only: %i[update destroy]

      def create
        authorize @quote, :manage_line_items?
        line_item = @quote.line_items.build(line_item_params)

        # Immutability enforced at model layer via before_create callback
        line_item.save!
        @quote.recalculate_totals!

        audit "created", resource: line_item, metadata: { quote_id: @quote.id }
        render_success line_item.as_api_json, status: :created
      end

      def update
        authorize @quote, :manage_line_items?
        @line_item.update!(line_item_params)
        @quote.recalculate_totals!

        audit "updated", resource: @line_item, metadata: { changed: @line_item.previous_changes.keys }
        render_success @line_item.as_api_json
      end

      def destroy
        authorize @quote, :manage_line_items?
        @line_item.destroy!
        @quote.recalculate_totals!

        audit "deleted", resource: @line_item
        head :no_content
      end

      private

      def set_quote
        @quote = policy_scope(Quote).find(params[:quote_id])
      end

      def set_line_item
        @line_item = @quote.line_items.find(params[:id])
      end

      def line_item_params
        params.require(:quote_line_item).permit(
          :procedure_code, :label, :tooth_location, :quantity, :position,
          :unit_fee, :reimbursement_base, :reimbursement_rate,
          :reimbursement_amount, :patient_share, :overage
        )
      end
    end
  end
end
