# frozen_string_literal: true

module Api
  module V1
    # Devis / quotes — routes REST `/api/v1/quotes` et alias Logosw `/api/v1/devis`
    # (même contrôleur, payload type turboapp sur les chemins `.../devis`).
    class QuotesController < Api::V1::BaseController
      before_action :set_quote, only: %i[
        show update destroy pdf send_to_patient sign reject expire
      ]

      def index
        quotes = policy_scope(Quote)
                 .includes(:line_items, :practitioner, patient_record: :patient)
                 .then { |s| filter_by_patient_record(s) }
                 .then { |s| filter_by_status(s) }
                 .order(created_at: :desc)
                 .page(page_param).per(per_page_param)

        authorize Quote

        if logosw_devis_request?
          render_success quotes.map(&:to_logosw_json)
        else
          render_success quotes_payload(quotes)
        end
      end

      def show
        authorize @quote
        audit "read", resource: @quote
        render_success serialize_quote(@quote)
      end

      def create
        result = resolve_create_context!
        return if performed?
        return if result.nil?

        patient_record, attrs = result

        practitioner = resolve_practitioner!(patient_record: patient_record,
                                             practitioner_id: attrs[:practitioner_id])

        quote = Quote.new(
          patient_record: patient_record,
          organization: current_organization,
          practitioner: practitioner,
          treatment_plan_id: attrs[:treatment_plan_id].presence || attrs[:plan_de_traitement_id],
          valid_until: attrs[:valid_until],
          notes: attrs[:notes]
        )
        authorize quote

        ActiveRecord::Base.transaction do
          quote.save!
          build_line_items_from_logosw!(quote, attrs[:lignes_attributes] || attrs[:line_items_attributes])
          quote.recalculate_totals! if quote.line_items.any?
        end

        audit "created", resource: quote
        render_success serialize_quote(quote.reload), status: :created
      rescue ActiveRecord::RecordNotFound => e
        render_error("not_found", e.message, status: :not_found)
      rescue ActiveRecord::RecordInvalid => e
        render_error("validation_failed", e.record.errors.full_messages.to_sentence,
                     status: :unprocessable_entity)
      end

      def update
        authorize @quote
        @quote.update!(quote_update_params)

        audit "updated", resource: @quote, metadata: { changed: @quote.previous_changes.keys }
        render_success serialize_quote(@quote)
      end

      def destroy
        authorize @quote, :destroy?
        @quote.destroy!

        audit "deleted", resource: @quote
        head :no_content
      end

      def pdf
        authorize @quote, :pdf?
        binary = ::Logosw::Quotes::ExportPdf.new(quote: @quote).call
        filename = "#{@quote.quote_number.parameterize.presence || 'devis'}.pdf"
        send_data binary,
                  filename: filename,
                  type: "application/pdf",
                  disposition: "attachment"
      rescue ::Logosw::Quotes::ExportPdf::Error => e
        render_error("pdf_failed", e.message, status: :internal_server_error)
      end

      def send_to_patient
        authorize @quote, :send_to_patient?
        @quote.send_to_patient!

        audit "status_changed", resource: @quote, metadata: { new_status: "sent" }
        render_success serialize_quote(@quote.reload)
      rescue AASM::InvalidTransition => e
        render_error("invalid_transition", e.message, status: :unprocessable_entity)
      end

      def sign
        authorize @quote, :sign?
        @quote.sign!
        if params[:docuseal_submission_id].present?
          @quote.update!(signature_submission_id: params[:docuseal_submission_id].to_s)
        end

        audit "status_changed", resource: @quote, metadata: { new_status: "signed" }
        render_success serialize_quote(@quote.reload)
      rescue AASM::InvalidTransition => e
        render_error("invalid_transition", e.message, status: :unprocessable_entity)
      end

      def reject
        authorize @quote, :reject?
        @quote.reject!

        audit "status_changed", resource: @quote, metadata: { new_status: "rejected" }
        render_success serialize_quote(@quote.reload)
      rescue AASM::InvalidTransition => e
        render_error("invalid_transition", e.message, status: :unprocessable_entity)
      end

      def expire
        authorize @quote, :expire?
        @quote.expire!

        audit "status_changed", resource: @quote, metadata: { new_status: "expired" }
        render_success serialize_quote(@quote.reload)
      rescue AASM::InvalidTransition => e
        render_error("invalid_transition", e.message, status: :unprocessable_entity)
      end

      # GET .../by_dossier/:dossier_patient_id — `dossier_patient_id` = patient_record_id HDS.
      def by_patient_record
        authorize Quote
        dossier_id = params[:dossier_patient_id].presence || params[:patient_record_id]
        patient_record = policy_scope(PatientRecord).find(dossier_id)
        quotes = policy_scope(Quote)
                 .where(patient_record_id: patient_record.id)
                 .includes(:line_items, :practitioner)
                 .order(created_at: :desc)
        quotes = quotes.where(status: params[:status]) if params[:status].present?

        if logosw_devis_request?
          render_success quotes.map(&:to_logosw_json)
        else
          render_success quotes: quotes.map(&:as_api_json)
        end
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "Patient record not found", status: :not_found)
      end

      def pending_signature
        authorize Quote
        quotes = policy_scope(Quote)
                 .pending_signature
                 .includes(:line_items, :practitioner)
                 .order(created_at: :desc)

        if logosw_devis_request?
          render_success quotes.map(&:to_logosw_json)
        else
          render_success quotes: quotes.map(&:as_api_json)
        end
      end

      private

      def logosw_devis_request?
        request.path.include?("/devis")
      end

      def serialize_quote(q)
        logosw_devis_request? ? q.to_logosw_json : q.as_api_json
      end

      def set_quote
        @quote = policy_scope(Quote).find(params[:id])
      end

      def quote_update_params
        root = params[:quote].presence || params[:devis]
        if root.blank?
          raise ActionController::ParameterMissing, "quote"
        end

        root.permit(:valid_until, :notes)
      end

      def resolve_create_context!
        if params[:patient_record_id].present?
          begin
            pr = policy_scope(PatientRecord).find(params[:patient_record_id])
          rescue ActiveRecord::RecordNotFound
            render_error("not_found", "Patient record not found", status: :not_found)
            return nil
          end
          attrs = create_nested_params
          return [ pr, attrs || {} ]
        end

        root = params[:quote].presence || params[:devis]
        if root.blank?
          render_error("validation_failed", "quote or devis parameters required", status: :bad_request)
          return nil
        end

        permitted = root.permit(
          :patient_record_id, :dossier_patient_id, :practitioner_id,
          :treatment_plan_id, :plan_de_traitement_id, :valid_until, :notes,
          lignes_attributes: ligne_permit_keys,
          line_items_attributes: ligne_permit_keys
        )
        dossier_id = permitted[:patient_record_id].presence || permitted[:dossier_patient_id]
        if dossier_id.blank?
          render_error("validation_failed", "patient_record_id or dossier_patient_id is required",
                       status: :unprocessable_entity)
          return nil
        end

        begin
          pr = policy_scope(PatientRecord).find(dossier_id)
        rescue ActiveRecord::RecordNotFound
          render_error("not_found", "Patient record not found", status: :not_found)
          return nil
        end

        [ pr, permitted.to_h.deep_symbolize_keys ]
      end

      def create_nested_params
        root = params[:quote].presence || params[:devis]
        return {} if root.blank?

        root.permit(
          :practitioner_id, :treatment_plan_id, :plan_de_traitement_id, :valid_until, :notes,
          lignes_attributes: ligne_permit_keys,
          line_items_attributes: ligne_permit_keys
        ).to_h.deep_symbolize_keys
      end

      def ligne_permit_keys
        %i[
          libelle label honoraires unit_fee base_remboursement reimbursement_base
          taux_remboursement reimbursement_rate quantite quantity position
          localisation tooth_location code_ccam procedure_code
          montant_rembourse reimbursement_amount reste_a_charge patient_share
          depassement overage
        ]
      end

      def resolve_practitioner!(patient_record:, practitioner_id: nil)
        if practitioner_id.present?
          return Practitioner.find_by!(
            id: practitioner_id,
            organization_id: current_organization.id
          )
        end

        p = Practitioner.find_by(account: current_account, organization: current_organization)
        return p if p

        if patient_record.primary_practitioner &&
           patient_record.primary_practitioner.organization_id == current_organization.id
          return patient_record.primary_practitioner
        end

        Practitioner.where(organization_id: current_organization.id, status: "active")
                      .order(:created_at)
                      .first!
      end

      def build_line_items_from_logosw!(quote, lignes)
        return if lignes.blank?

        rows =
          case lignes
          when ActionController::Parameters
            h = lignes.to_unsafe_h
            h.is_a?(Hash) ? h.values : Array(lignes)
          when Hash
            lignes.values
          else
            Array(lignes)
          end

        rows.each_with_index do |row, idx|
          h = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
          h = h.symbolize_keys
          qty = (h[:quantite] || h[:quantity] || 1).to_i
          qty = 1 if qty < 1
          hon = BigDecimal((h[:honoraires] || h[:unit_fee]).to_s.presence || "0")
          unit_fee = if h[:unit_fee].present?
                       BigDecimal(h[:unit_fee].to_s)
                     else
                       (hon / qty).round(2)
                     end

          quote.line_items.create!(
            label: (h[:libelle] || h[:label]).to_s.presence || "Acte",
            tooth_location: (h[:localisation] || h[:tooth_location]).to_s.presence,
            procedure_code: (h[:code_ccam] || h[:procedure_code]).to_s.presence,
            quantity: qty,
            position: (h[:position] || idx).to_i,
            unit_fee: unit_fee,
            reimbursement_base: BigDecimal((h[:base_remboursement] || h[:reimbursement_base]).to_s.presence || "0"),
            reimbursement_rate: BigDecimal((h[:taux_remboursement] || h[:reimbursement_rate]).to_s.presence || "0"),
            reimbursement_amount: BigDecimal((h[:montant_rembourse] || h[:reimbursement_amount]).to_s.presence || "0"),
            patient_share: BigDecimal((h[:reste_a_charge] || h[:patient_share]).to_s.presence || "0"),
            overage: BigDecimal((h[:depassement] || h[:overage]).to_s.presence || "0")
          )
        end
      end

      def filter_by_patient_record(scope)
        params[:patient_record_id].present? ? scope.where(patient_record_id: params[:patient_record_id]) : scope
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def page_param
        (params[:page] || 1).to_i
      end

      def per_page_param
        [ (params[:per_page] || 25).to_i, 100 ].min
      end

      def quotes_payload(quotes)
        {
          quotes: quotes.map(&:as_api_json),
          meta: {
            current_page: quotes.current_page,
            total_pages:  quotes.total_pages,
            total_count:  quotes.total_count
          }
        }
      end
    end
  end
end
