# frozen_string_literal: true

class Rack::Attack
  # Allow health checks without throttling
  safelist("allow health check") do |req|
    req.path == "/up"
  end

  # Throttle login attempts by IP: 10 per minute
  throttle("api/auth/login by IP", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Throttle login attempts by email: 5 per minute
  # This limits credential-stuffing against a specific account
  throttle("api/auth/login by email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.params["email"]&.downcase&.strip&.presence
    end
  end

  # Throttle refresh token endpoint by IP: 30 per minute
  throttle("api/auth/refresh by IP", limit: 30, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/refresh" && req.post?
  end

  # Throttle all other API calls by IP: 300 per minute
  throttle("api general by IP", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Return JSON on throttled requests (not the default HTML response)
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ { error: { code: "too_many_requests", message: "Rate limit exceeded. Try again later." } }.to_json ]
    ]
  end
end
