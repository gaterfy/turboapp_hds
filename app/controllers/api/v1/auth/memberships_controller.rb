# frozen_string_literal: true

module Api
  module V1
    module Auth
      # Lists the organizations the authenticated practitioner can access.
      #
      # Required gates: valid JWT + MFA verified. We deliberately do NOT
      # require the X-Organization-Id header here, since this endpoint is
      # used precisely to discover which organizations the account belongs
      # to before picking one.
      #
      # Response payload:
      #   { data: [ { organization_id, name, slug, role, joined_at } ] }
      class MembershipsController < Api::BaseController
        before_action :authenticate_account!
        before_action :enforce_mfa!

        def index
          memberships = @current_account
                          .memberships
                          .active
                          .includes(:organization)
                          .joins(:organization)
                          .merge(Organization.active)

          render_success(memberships.map { |m| serialize(m) })
        end

        private

        def serialize(membership)
          org = membership.organization
          {
            organization_id: org.id,
            name:            org.name,
            slug:            org.slug,
            role:            membership.role,
            joined_at:       membership.created_at.iso8601
          }
        end

        # ------------------------------------------------------------
        # Authentication helpers — same shape as MfaController so this
        # endpoint stays usable BEFORE org resolution. Kept inlined to
        # avoid coupling with Api::V1::BaseController which mandates
        # X-Organization-Id (the very thing this endpoint helps choose).
        # ------------------------------------------------------------

        def authenticate_account!
          token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
          return render_error("unauthorized", "Missing Authorization header", status: :unauthorized) if token.blank?

          @current_payload = ::Auth::TokenVerifier.verify!(token)
          @current_account = Account.active.find(@current_payload["sub"])
        rescue ::Auth::TokenVerifier::ExpiredToken
          render_error "token_expired", "Access token has expired", status: :unauthorized
        rescue ::Auth::TokenVerifier::RevokedToken
          render_error "token_revoked", "Access token has been revoked", status: :unauthorized
        rescue ::Auth::TokenVerifier::InvalidToken => e
          render_error "token_invalid", e.message, status: :unauthorized
        rescue ActiveRecord::RecordNotFound
          render_error "unauthorized", "Account not found", status: :unauthorized
        end

        def enforce_mfa!
          return if performed?
          return unless @current_account
          return if @current_account.patient?
          return if @current_payload && @current_payload["mfa_verified"] == true

          render_error(
            "mfa_required",
            "Strong authentication (MFA) is required for this account",
            status: :forbidden
          )
        end
      end
    end
  end
end
