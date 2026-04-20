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
        qid = params[:quote_id].presence || params[:devis_id].presence || params[:devi_id]
        @quote = policy_scope(Quote).find(qid)
      end

      def set_line_item
        @line_item = @quote.line_items.find(params[:id])
      end

      def line_item_params
        raw = params[:quote_line_item].presence || params[:ligne_devis]
        if raw.blank?
          raise ActionController::ParameterMissing,
                "param is missing or the value is empty: quote_line_item or ligne_devis"
        end

        permitted = raw.permit(
          :procedure_code, :label, :tooth_location, :quantity, :position,
          :unit_fee, :reimbursement_base, :reimbursement_rate,
          :reimbursement_amount, :patient_share, :overage,
          :libelle, :localisation, :code_ccam, :honoraires, :base_remboursement,
          :taux_remboursement, :montant_rembourse, :reste_a_charge, :depassement,
          :quantite
        )
        normalize_line_item_params(permitted)
      end

      def normalize_line_item_params(p)
        h = p.to_h.symbolize_keys
        qty = (h[:quantite] || h[:quantity] || 1).to_i
        qty = 1 if qty < 1
        hon = BigDecimal((h[:honoraires] || h[:unit_fee]).to_s.presence || "0")
        unit_fee = h[:unit_fee].present? ? BigDecimal(h[:unit_fee].to_s) : (hon / qty).round(2)

        ActionController::Parameters.new(
          label: (h[:libelle] || h[:label]).to_s.presence || "Acte",
          tooth_location: (h[:localisation] || h[:tooth_location]).to_s.presence,
          procedure_code: (h[:code_ccam] || h[:procedure_code]).to_s.presence,
          quantity: qty,
          position: (h[:position] || 0).to_i,
          unit_fee: unit_fee,
          reimbursement_base: BigDecimal((h[:base_remboursement] || h[:reimbursement_base]).to_s.presence || "0"),
          reimbursement_rate: BigDecimal((h[:taux_remboursement] || h[:reimbursement_rate]).to_s.presence || "0"),
          reimbursement_amount: BigDecimal((h[:montant_rembourse] || h[:reimbursement_amount]).to_s.presence || "0"),
          patient_share: BigDecimal((h[:reste_a_charge] || h[:patient_share]).to_s.presence || "0"),
          overage: BigDecimal((h[:depassement] || h[:overage]).to_s.presence || "0")
        ).permit!
      end
    end
  end
end
