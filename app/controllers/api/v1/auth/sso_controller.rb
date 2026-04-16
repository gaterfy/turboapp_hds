# frozen_string_literal: true

module Api
  module V1
    module Auth
      # POST /api/v1/auth/sso/exchange
      #
      # Accepts a signed assertion JWT from turboapp (dunia_builder hub),
      # verifies it, provisions or finds the Account, and returns a standard
      # access_token + refresh_token pair — same format as sessions#create.
      class SsoController < Api::BaseController
        ALGORITHM = "HS256"

        # Seuls ces roles peuvent etre provisionnes via SSO depuis turboapp.
        # Le role est porte par l'assertion (claim "role") et verifie strictement.
        ALLOWED_SSO_ROLES = %w[practitioner].freeze

        def exchange
          assertion = params[:assertion]
          return render_error("missing_assertion", "assertion parameter is required", status: :bad_request) if assertion.blank?

          payload = decode_and_verify!(assertion)
          return if performed?

          account = find_or_provision_account!(payload)
          return if performed?

          token_data    = ::Auth::TokenIssuer.issue_access_token(account)
          refresh_token = ::Auth::TokenIssuer.issue_refresh_token(account, request: request)

          Audit::LoggerService.log(
            action: "sso_login",
            account: account,
            metadata: {
              source: "turboapp",
              merchant_id: payload["merchant_id"],
              merchant_email: payload["sub"]
            },
            request: request
          )

          render_success({
            access_token:             token_data[:access_token],
            access_token_expires_at:  token_data[:expires_at],
            refresh_token:            refresh_token.token,
            refresh_token_expires_at: refresh_token.expires_at,
            account: {
              id:           account.id,
              email:        account.email,
              account_type: account.account_type
            }
          }, status: :created)
        end

        private

        # ── Assertion verification ────────────────────────────────────────────

        def decode_and_verify!(token)
          payload = JWT.decode(token, sso_secret, true, algorithms: [ALGORITHM]).first

          unless payload["iss"] == "turboapp" && payload["aud"] == "turboapp_hds"
            raise JWT::DecodeError, "Invalid issuer or audience"
          end

          # Validation stricte du role : seuls les roles explicitement autorises
          # peuvent provisionner/acceder a un Account HDS via SSO.
          role = payload["role"]
          if role.blank? || !ALLOWED_SSO_ROLES.include?(role)
            raise JWT::DecodeError, "Role '#{role}' is not allowed for SSO"
          end

          jti = payload["jti"]
          raise JWT::DecodeError, "Missing jti claim" if jti.blank?

          if SsoAssertionDenylist.consumed?(jti)
            raise JWT::DecodeError, "Assertion already consumed (replay)"
          end

          SsoAssertionDenylist.consume!(jti: jti, exp: payload["exp"])

          payload
        rescue JWT::ExpiredSignature
          render_error("assertion_expired", "SSO assertion has expired", status: :unauthorized) and return
        rescue JWT::DecodeError => e
          Audit::LoggerService.log(
            action: "sso_assertion_rejected",
            metadata: { reason: e.message, merchant_email: safe_sub(token) },
            request: request
          )
          render_error("invalid_assertion", e.message, status: :unauthorized) and return
        end

        # Decode le sub sans verification (pour log uniquement, apres echec).
        def safe_sub(token)
          JWT.decode(token, nil, false).first["sub"]
        rescue StandardError
          nil
        end

        # ── Account provisioning ──────────────────────────────────────────────

        def find_or_provision_account!(payload)
          email         = payload["sub"]&.downcase&.strip
          expected_role = payload["role"]
          account       = Account.find_by(email: email)

          if account
            unless account.active?
              render_error("account_inactive", "Account is deactivated", status: :forbidden)
              return nil
            end

            # Securite : un compte existant ne peut pas etre "upgrade" via SSO
            # vers un autre type (ex: patient -> practitioner).
            unless account.account_type == expected_role
              Audit::LoggerService.log(
                action: "sso_account_type_mismatch",
                account: account,
                metadata: {
                  existing_type: account.account_type,
                  requested_role: expected_role,
                  merchant_id: payload["merchant_id"]
                },
                request: request
              )
              render_error(
                "account_type_mismatch",
                "Existing account type does not match SSO role",
                status: :forbidden
              )
              return nil
            end

            return account
          end

          Account.create!(
            email:        email,
            password:     SecureRandom.hex(32),
            account_type: expected_role,
            active:       true
          )
        end

        def sso_secret
          secret = ENV["SSO_ASSERTION_SECRET"]
          raise "SSO_ASSERTION_SECRET is not configured" if secret.blank?
          secret
        end
      end
    end
  end
end
