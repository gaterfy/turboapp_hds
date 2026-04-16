# frozen_string_literal: true

module Api
  module V1
    # Base for all authenticated, organization-scoped endpoints.
    #
    # Security invariants enforced here:
    #   1. Every request must carry a valid JWT access token.
    #   2. Every request must target a specific Organization via X-Organization-Id header.
    #   3. The requesting account must have an active Membership in that Organization.
    #
    # No clinical resource should ever be accessible without passing these three gates.
    class BaseController < Api::BaseController
      include Pundit::Authorization

      before_action :authenticate_account!
      before_action :resolve_organization!

      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      attr_reader :current_account, :current_organization, :current_membership

      private

      def authenticate_account!
        token = bearer_token
        return render_error("unauthorized", "Missing Authorization header", status: :unauthorized) if token.blank?

        payload = Auth::TokenVerifier.verify!(token)
        @current_account = Account.active.find(payload["sub"])
      rescue Auth::TokenVerifier::ExpiredToken
        render_error "token_expired", "Access token has expired", status: :unauthorized
      rescue Auth::TokenVerifier::RevokedToken
        render_error "token_revoked", "Access token has been revoked", status: :unauthorized
      rescue Auth::TokenVerifier::InvalidToken => e
        render_error "token_invalid", e.message, status: :unauthorized
      rescue ActiveRecord::RecordNotFound
        render_error "unauthorized", "Account not found", status: :unauthorized
      end

      def resolve_organization!
        organization_id = request.headers["X-Organization-Id"]
        return render_error("missing_organization", "X-Organization-Id header is required", status: :bad_request) if organization_id.blank?

        @membership = current_account.memberships.active.find_by(organization_id: organization_id)
        return render_error("forbidden", "Account does not belong to this organization", status: :forbidden) unless @membership

        @current_organization = @membership.organization
      end

      def audit(action, resource: nil, metadata: {})
        Audit::LoggerService.log(
          action: action,
          account: current_account,
          organization: current_organization,
          resource: resource,
          metadata: metadata,
          request: request
        )
      end

      def require_role!(*roles)
        unless roles.map(&:to_s).include?(current_membership.role)
          audit "forbidden_action", metadata: { required_roles: roles, actual_role: current_membership.role }
          render_error "forbidden", "Insufficient permissions for this action", status: :forbidden
        end
      end

      def pundit_user
        { account: current_account, membership: current_membership }
      end

      def render_forbidden(_exception = nil)
        render_error "forbidden", "You are not authorized to perform this action", status: :forbidden
      end

      def bearer_token
        request.headers["Authorization"]&.remove("Bearer ")&.strip
      end
    end
  end
end
