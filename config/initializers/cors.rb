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

# En dev uniquement, on autorise tous les ports localhost/127.0.0.1.
# `flutter run -d chrome` attribue un port aleatoire (ex: 51730) qu'on ne
# peut pas faire figurer dans une liste statique.
if Rails.env.development?
  allowed_origins = allowed_origins + [
    %r{\Ahttp://localhost(?::\d+)?\z},
    %r{\Ahttp://127\.0\.0\.1(?::\d+)?\z}
  ]
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
