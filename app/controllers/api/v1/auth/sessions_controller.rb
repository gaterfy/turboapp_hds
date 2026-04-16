# frozen_string_literal: true

module Api
  module V1
    module Auth
      # POST   /api/v1/auth/login   – authenticate and receive token pair
      # DELETE /api/v1/auth/logout  – revoke current access token and refresh token
      class SessionsController < Api::BaseController
        before_action :authenticate_for_logout!, only: :destroy

        def create
          account = Account.find_by(email: params[:email]&.downcase&.strip)

          unless account&.valid_password?(params[:password])
            log_failed_login(account)
            return render_error "invalid_credentials", "Invalid email or password", status: :unauthorized
          end

          unless account.active?
            return render_error "account_inactive", "Account is deactivated", status: :forbidden
          end

          if account.access_locked?
            return render_error "account_locked", "Account is locked due to too many failed attempts", status: :forbidden
          end

          account.unlock_access! if account.access_locked?

          token_data = ::Auth::TokenIssuer.issue_access_token(account)
          refresh_token = ::Auth::TokenIssuer.issue_refresh_token(account, request: request)

          Audit::LoggerService.log(
            action: "login_success",
            account: account,
            metadata: { account_type: account.account_type },
            request: request
          )

          render_success({
            access_token: token_data[:access_token],
            access_token_expires_at: token_data[:expires_at],
            refresh_token: refresh_token.token,
            refresh_token_expires_at: refresh_token.expires_at,
            account: {
              id: account.id,
              email: account.email,
              account_type: account.account_type
            }
          }, status: :created)
        end

        def destroy
          jti = @current_payload["jti"]
          exp = @current_payload["exp"]

          JwtDenylist.revoke!(jti: jti, exp: exp)

          # Also revoke all active refresh tokens for this account
          @auth_account.refresh_tokens.active.each { |rt| rt.revoke!(reason: "logout") }

          Audit::LoggerService.log(
            action: "logout",
            account: @auth_account,
            metadata: { jti: jti },
            request: request
          )

          head :no_content
        end

        private

        def authenticate_for_logout!
          token = request.headers["Authorization"]&.remove("Bearer ")&.strip
          return render_error("unauthorized", "Missing Authorization header", status: :unauthorized) if token.blank?

          @current_payload = ::Auth::TokenVerifier.verify!(token)
          @auth_account = Account.find(@current_payload["sub"])
        rescue ::Auth::TokenVerifier::Error => e
          render_error "unauthorized", e.message, status: :unauthorized
        end

        def log_failed_login(account)
          if account
            account.increment_failed_attempts
            account.lock_access! if account.failed_attempts >= Devise.maximum_attempts
          end

          Audit::LoggerService.log(
            action: "login_failure",
            account: account,
            metadata: { email: params[:email]&.downcase&.strip, locked: account&.access_locked? },
            request: request
          )
        end
      end
    end
  end
end
