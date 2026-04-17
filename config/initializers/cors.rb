# frozen_string_literal: true

# Fail-closed in production: if ALLOWED_ORIGINS is not set (or empty),
# we refuse to boot rather than silently falling back to localhost.
# In development/test we allow localhost by default for convenience.
origins_env = ENV["ALLOWED_ORIGINS"].to_s.strip

if Rails.env.production? && origins_env.blank?
  raise "ALLOWED_ORIGINS is required in production (no default allowed for HDS)"
end

allowed_origins = if origins_env.present?
  origins_env.split(",").map(&:strip).reject(&:blank?)
else
  [ "http://localhost:3000", "http://localhost:5173" ]
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization],
             max_age: 600,
             credentials: false
  end
end
