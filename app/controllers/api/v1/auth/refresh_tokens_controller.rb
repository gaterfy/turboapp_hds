# frozen_string_literal: true

module Api
  module V1
    module Auth
      # POST /api/v1/auth/refresh
      # Exchanges a valid refresh token for a new access token + rotated refresh token.
      # The old refresh token is immediately revoked (rotation strategy).
      class RefreshTokensController < Api::BaseController
        def create
          token_value = params[:refresh_token].presence
          token_value = token_value.is_a?(String) ? token_value.strip.presence : nil
          return render_error("missing_token", "refresh_token is required", status: :bad_request) if token_value.blank?

          refresh_token = RefreshToken.find_by(token: token_value)

          unless refresh_token&.usable?
            Audit::LoggerService.log(
              action: "token_refresh_failed",
              metadata: { reason: token_failure_reason(refresh_token) },
              request: request
            )
            return render_error "invalid_token", "Refresh token is invalid, expired or revoked", status: :unauthorized
          end

          account = refresh_token.account
          unless account.active?
            return render_error "account_inactive", "Account is deactivated", status: :forbidden
          end

          # Rotation: revoke current refresh token before issuing a new pair
          refresh_token.revoke!(reason: "rotated")

          new_token_data = ::Auth::TokenIssuer.issue_access_token(account)
          new_refresh_token = ::Auth::TokenIssuer.issue_refresh_token(account, request: request)

          Audit::LoggerService.log(
            action: "token_refreshed",
            account: account,
            metadata: { previous_jti: refresh_token.id },
            request: request
          )

          render_success({
            access_token: new_token_data[:access_token],
            access_token_expires_at: new_token_data[:expires_at],
            refresh_token: new_refresh_token.token,
            refresh_token_expires_at: new_refresh_token.expires_at
          }, status: :created)
        end

        private

        def token_failure_reason(token)
          return "not_found" if token.nil?
          return "revoked" if token.revoked?
          return "expired" if token.expired?
          "unknown"
        end
      end
    end
  end
end
