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
      Rails.logger.error("#{exception.class}: #{exception.message}\n#{exception.backtrace&.first(10)&.join("\n")}")
      render_error "internal_error", "An unexpected error occurred", status: :internal_server_error
    end
  end
end
