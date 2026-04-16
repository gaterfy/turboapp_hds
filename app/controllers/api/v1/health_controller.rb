# frozen_string_literal: true

module Api
  module V1
    # Public endpoint — no authentication required.
    # Used by Scalingo load balancer and monitoring tools.
    class HealthController < Api::BaseController
      def show
        db_ok  = database_reachable?
        status = db_ok ? :ok : :service_unavailable

        render json: {
          status:    db_ok ? "ok" : "degraded",
          version:   Rails.application.config.version,
          env:       Rails.env,
          timestamp: Time.current.iso8601,
          checks: {
            database: db_ok ? "ok" : "unreachable"
          }
        }, status: status
      end

      private

      def database_reachable?
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue StandardError
        false
      end
    end
  end
end
