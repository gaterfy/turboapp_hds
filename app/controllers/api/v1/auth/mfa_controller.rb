# frozen_string_literal: true

module Api
  module V1
    module Auth
      # MFA (TOTP) management endpoints.
      #
      # Flow:
      #   1. POST /setup     — generate secret + return provisioning URI (QR)
      #   2. POST /confirm   — verify first OTP code → enable MFA + return backup codes
      #   3. POST /verify    — verify OTP during login challenge (issues mfa_verified token)
      #   4. DELETE /disable — disable MFA (requires current OTP as confirmation)
      class MfaController < Api::BaseController
        before_action :authenticate_for_mfa!

        def setup
          return render_error "mfa_already_enabled", "MFA is already enabled", status: :unprocessable_entity if @mfa_account.mfa_enabled?

          secret = @mfa_account.setup_mfa!
          uri    = @mfa_account.totp_provisioning_uri

          Audit::LoggerService.log(action: "mfa_setup_initiated", account: @mfa_account, request: request)

          render_success({
            secret:           secret,
            provisioning_uri: uri,
            qr_svg:           qr_svg(uri)
          })
        end

        def confirm
          backup_codes = @mfa_account.enable_mfa!(params[:otp_code])

          if backup_codes
            Audit::LoggerService.log(action: "mfa_enabled", account: @mfa_account, request: request)
            render_success({ backup_codes: backup_codes }, status: :created)
          else
            render_error "mfa_invalid_code", "Invalid or expired OTP code", status: :unprocessable_entity
          end
        end

        def verify
          return render_error "mfa_not_enabled", "MFA is not enabled for this account", status: :unprocessable_entity unless @mfa_account.mfa_enabled?

          if @mfa_account.verify_mfa!(params[:otp_code])
            token_data = ::Auth::TokenIssuer.issue_access_token(@mfa_account, mfa_verified: true)
            Audit::LoggerService.log(action: "mfa_verified", account: @mfa_account, request: request)

            render_success({
              access_token:           token_data[:access_token],
              access_token_expires_at: token_data[:expires_at],
              mfa_verified:           true
            })
          else
            Audit::LoggerService.log(action: "mfa_failed", account: @mfa_account, request: request)
            render_error "mfa_invalid_code", "Invalid or expired OTP code", status: :unauthorized
          end
        end

        def disable
          return render_error "mfa_not_enabled", "MFA is not enabled", status: :unprocessable_entity unless @mfa_account.mfa_enabled?

          unless @mfa_account.verify_mfa!(params[:otp_code])
            return render_error "mfa_invalid_code", "Invalid OTP code — provide current code to disable MFA", status: :unauthorized
          end

          @mfa_account.disable_mfa!
          Audit::LoggerService.log(action: "mfa_disabled", account: @mfa_account, request: request)
          head :no_content
        end

        private

        def authenticate_for_mfa!
          token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
          return render_error("unauthorized", "Missing Authorization header", status: :unauthorized) if token.blank?

          payload = ::Auth::TokenVerifier.verify!(token)
          @mfa_account = Account.active.find(payload["sub"])
        rescue ::Auth::TokenVerifier::Error => e
          render_error "unauthorized", e.message, status: :unauthorized
        rescue ActiveRecord::RecordNotFound
          render_error "unauthorized", "Account not found", status: :unauthorized
        end

        def qr_svg(uri)
          qr = RQRCode::QRCode.new(uri)
          qr.as_svg(offset: 0, color: "000", shape_rendering: "crispEdges",
                    module_size: 4, standalone: true)
        rescue StandardError
          nil
        end
      end
    end
  end
end
