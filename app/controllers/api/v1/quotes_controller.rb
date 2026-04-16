# frozen_string_literal: true

module Api
  module V1
    class QuotesController < Api::V1::BaseController
      before_action :set_quote, only: %i[show update send_to_patient sign reject expire]

      def index
        quotes = policy_scope(Quote)
                 .includes(:line_items, :practitioner)
                 .then { |s| filter_by_patient_record(s) }
                 .then { |s| filter_by_status(s) }
                 .order(created_at: :desc)
                 .page(params[:page]).per(params[:per_page] || 25)

        authorize Quote
        render_success quotes_payload(quotes)
      end

      def show
        authorize @quote
        audit "read", resource: @quote
        render_success @quote.as_api_json
      end

      def create
        patient_record = policy_scope(PatientRecord).find(params[:patient_record_id])
        quote = Quote.new(quote_params.merge(
          patient_record: patient_record,
          organization: current_organization,
          practitioner: current_practitioner!
        ))
        authorize quote

        quote.save!
        audit "created", resource: quote
        render_success quote.as_api_json, status: :created
      end

      def update
        authorize @quote
        @quote.update!(quote_params)

        audit "updated", resource: @quote, metadata: { changed: @quote.previous_changes.keys }
        render_success @quote.as_api_json
      end

      def send_to_patient
        authorize @quote, :send_to_patient?
        @quote.send_to_patient!

        audit "status_changed", resource: @quote, metadata: { new_status: "sent" }
        render_success @quote.as_api_json
      end

      def sign
        authorize @quote, :sign?
        @quote.sign!

        audit "status_changed", resource: @quote, metadata: { new_status: "signed" }
        render_success @quote.as_api_json
      end

      def reject
        authorize @quote, :reject?
        @quote.reject!

        audit "status_changed", resource: @quote, metadata: { new_status: "rejected" }
        render_success @quote.as_api_json
      end

      def expire
        authorize @quote, :expire?
        @quote.expire!

        audit "status_changed", resource: @quote, metadata: { new_status: "expired" }
        render_success @quote.as_api_json
      end

      private

      def set_quote
        @quote = policy_scope(Quote).find(params[:id])
      end

      def quote_params
        params.require(:quote).permit(:valid_until, :notes)
      end

      def filter_by_patient_record(scope)
        params[:patient_record_id].present? ? scope.where(patient_record_id: params[:patient_record_id]) : scope
      end

      def filter_by_status(scope)
        params[:status].present? ? scope.where(status: params[:status]) : scope
      end

      def current_practitioner!
        Practitioner.find_by!(account: current_account, organization: current_organization)
      rescue ActiveRecord::RecordNotFound
        raise ActiveRecord::RecordNotFound, "No practitioner profile found for this account in this organization"
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
