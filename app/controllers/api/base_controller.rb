# frozen_string_literal: true

module Api
  # Root for all API controllers.
  # Inherits from ActionController::API to skip cookie/session/CSRF middleware.
  class BaseController < ActionController::API
    rescue_from StandardError, with: :render_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

    private

    def render_success(data, status: :ok)
      render json: { data: data }, status: status
    end

    def render_error(code, message, status:, details: nil)
      body = { error: { code: code, message: message } }
      body[:error][:details] = details if details.present?
      render json: body, status: status
    end

    def render_not_found(exception = nil)
      render_error "not_found", exception&.message || "Resource not found", status: :not_found
    end

    def render_unprocessable_entity(exception)
      render_error "validation_failed", "Validation failed",
                   status: :unprocessable_entity,
                   details: exception.record.errors.full_messages
    end

    def render_internal_error(exception)
      # Re-raise in test so the real error is visible and not swallowed by the generic handler
      raise exception if Rails.env.test?

      # Structured log — exception class only, no message.
      # Messages frequently contain PII (e.g. ActiveRecord "Validation failed:
      # Email foo@bar.fr already taken"). We keep a correlation id so ops can
      # locate the full trace in the APM/Sentry backend when needed.
      error_id = SecureRandom.uuid
      Rails.logger.error(
        "[internal_error] id=#{error_id} class=#{exception.class} " \
        "request_id=#{request.request_id} path=#{request.path}"
      )
      Rails.logger.debug { exception.backtrace&.first(10)&.join("\n") }

      render_error "internal_error",
                   "An unexpected error occurred",
                   status: :internal_server_error,
                   details: { error_id: error_id }
    end
  end
end
