# frozen_string_literal: true

class Rack::Attack
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  #
  # Rack::Attack runs before Rails, so it does NOT parse JSON bodies.
  # Our API clients send `application/json`, which means `req.params` is empty
  # for POST JSON requests (only query-string params are there).
  # We parse the body once and memoize on `req.env` so multiple throttles can
  # reuse the result without re-reading the body (the body is rewound).
  def self.parsed_json_body(req)
    req.env["rack.attack.parsed_body"] ||= _parse_json_body(req)
  end

  def self._parse_json_body(req)
    return {} unless req.content_type&.include?("application/json")
    return {} unless req.body

    raw = req.body.read
    req.body.rewind
    return {} if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end

  def self.json_param(req, key)
    parsed_json_body(req)[key]
  end

  # ---------------------------------------------------------------------------
  # Safelist
  # ---------------------------------------------------------------------------
  safelist("allow health check") do |req|
    req.path == "/up"
  end

  # ---------------------------------------------------------------------------
  # Login
  # ---------------------------------------------------------------------------
  throttle("api/auth/login by IP", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Credential stuffing targeting a specific account, regardless of IP.
  throttle("api/auth/login by email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      json_param(req, "email").to_s.downcase.strip.presence
    end
  end

  # ---------------------------------------------------------------------------
  # Refresh token
  # ---------------------------------------------------------------------------
  throttle("api/auth/refresh by IP", limit: 30, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/refresh" && req.post?
  end

  # ---------------------------------------------------------------------------
  # SSO exchange
  # ---------------------------------------------------------------------------
  # Brute-force on signed JWT forgery is already computationally impossible
  # with HS256 + 256-bit secret, but this protects against accidental loops
  # in client apps, and it caps denylist growth.
  throttle("api/auth/sso/exchange by IP", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/sso/exchange" && req.post?
  end

  # ---------------------------------------------------------------------------
  # General API throttle
  # ---------------------------------------------------------------------------
  throttle("api general by IP", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # ---------------------------------------------------------------------------
  # Fail2Ban: permanent(-ish) ban for repeat offenders on auth endpoints
  # ---------------------------------------------------------------------------
  blocklist("fail2ban/auth-abusers") do |req|
    Rack::Attack::Fail2Ban.filter(
      "auth-abuser-#{req.ip}",
      maxretry: 3,
      findtime: 10.minutes,
      bantime:  1.hour
    ) do
      (
        (req.path == "/api/v1/auth/login"        && req.post?) ||
        (req.path == "/api/v1/auth/sso/exchange" && req.post?)
      ) && req.env["rack.attack.matched"].present?
    end
  end

  # ---------------------------------------------------------------------------
  # JSON response on throttle / block
  # ---------------------------------------------------------------------------
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After"  => retry_after.to_s
      },
      [ { error: { code: "too_many_requests", message: "Rate limit exceeded. Try again later." } }.to_json ]
    ]
  end

  self.blocklisted_responder = lambda do |_request|
    [
      403,
      { "Content-Type" => "application/json" },
      [ { error: { code: "blocked", message: "Access temporarily blocked due to abusive behavior." } }.to_json ]
    ]
  end
end
