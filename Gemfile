source "https://rubygems.org"

# Exact pin avoids auto-upgrade on Scalingo (which would pick the latest 3.3.x
# and fail if the active stack doesn't support it yet).
ruby "3.3.9"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

gem "kaminari"
gem "rotp"
gem "rqrcode"
gem "aasm"

# Authentication and security
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 3.1"
gem "devise", "~> 4.9"
gem "rack-attack"
gem "rack-cors"
gem "pundit"
gem "prawn"
# Prawn requires matrix; Ruby 3.1+ no longer bundles it as a default gem.
gem "matrix"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # Charge `.env` au boot (SSO_ASSERTION_SECRET, ALLOWED_ORIGINS, etc.) sans
  # `source .env && rails s` — evite les 500 sur /auth/sso/exchange en local.
  gem "dotenv-rails", "~> 3.1"
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
end

group :test do
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end
