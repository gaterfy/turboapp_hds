Rails.application.routes.draw do
  # Infrastructure health – used by Scalingo load balancer
  get "up" => "rails/health#show", as: :rails_health_check

  # devise_for :accounts is intentionally removed.
  # Auth is handled via custom API controllers below.

  namespace :api do
    namespace :v1 do
      # Public health endpoint (no auth)
      get "health", to: "health#show"

      # Authentication (no JWT required)
      namespace :auth do
        post   "login",   to: "sessions#create"
        delete "logout",  to: "sessions#destroy"
        post   "refresh", to: "refresh_tokens#create"

        # SSO cross-app: echange assertion turboapp contre tokens locaux
        post "sso/exchange", to: "sso#exchange"

        # MFA (requires valid access token)
        scope :mfa do
          post   "setup",   to: "mfa#setup"
          post   "confirm", to: "mfa#confirm"
          post   "verify",  to: "mfa#verify"
          delete "disable", to: "mfa#disable"
        end
      end

      # Authenticated + organization-scoped endpoints
      resource :profile, only: :show

      # Clinical resources
      resources :practitioners, only: %i[index show create update] do
        member { patch :deactivate }
      end

      resources :patients, only: %i[index show create update]

      resources :patient_records, only: %i[index show create update] do
        member { patch :archive }
      end

      resources :appointments, only: %i[index show create update] do
        member { patch :cancel }
      end

      # Clinical documents
      resources :consultations, only: %i[index show create update] do
        member do
          patch :complete
          patch :seal
          post  :ai_report
        end
      end

      # Treatment plans
      resources :treatment_plans, only: %i[index show create update] do
        member do
          patch :accept
          patch :start
          patch :complete
          patch :cancel
        end
        resources :items, only: %i[create update destroy],
                          controller: "treatment_plan_items"
      end

      resources :quotes, only: %i[index show create update] do
        member do
          patch :send_to_patient
          patch :sign
          patch :reject
          patch :expire
        end
        resources :line_items, only: %i[create update destroy],
                               controller: "quote_line_items"
      end

      resources :prescriptions, only: %i[index show create update] do
        member do
          patch :sign
          patch :deliver
          patch :cancel
        end
        resources :line_items, only: %i[create update destroy],
                               controller: "prescription_line_items"
      end
      # Patient portal (patient accounts only)
      namespace :patient_portal do
        resource :record, only: :show, controller: "records" do
          get :appointments
          get :consultations
          get :quotes
          get :prescriptions
          get :treatment_plans
        end
      end
    end
  end
end
