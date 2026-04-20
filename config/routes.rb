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

        # Lists organizations the authenticated account can access (used
        # by clients to display the org picker before resolving an org).
        get "memberships", to: "memberships#index"
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

      # Alias Logosw (turboapp) — dossier clinique par patient_id
      get "dossier_patients/by_patient/:patient_id", to: "patient_records#by_patient"

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

      # Alias Logosw — liste des consultations pour un dossier (patient_record_id)
      get "consultations/by_dossier/:dossier_patient_id", to: "consultations#by_dossier"

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

      resources :quotes, only: %i[index show create update destroy] do
        member do
          get :pdf
          # turboapp / client Logosw : POST ; API REST : PATCH également accepté
          match :send_to_patient, via: %i[post patch]
          match :sign, via: %i[post patch]
          match :reject, via: %i[post patch]
          patch :expire
        end
        collection do
          get "by_dossier/:dossier_patient_id", action: :by_patient_record, as: :by_dossier
          get :pending_signature
        end
        resources :line_items, only: %i[create update destroy],
                               controller: "quote_line_items"
      end

      # Alias Logosw « devis » (turboapp) — même contrôleur et logique que `quotes`.
      resources :devis, controller: "quotes", only: %i[index show create update destroy] do
        member do
          get :pdf
          match :send_to_patient, via: %i[post patch]
          match :sign, via: %i[post patch]
          match :reject, via: %i[post patch]
          patch :expire
        end
        collection do
          get "by_dossier/:dossier_patient_id", action: :by_patient_record
          get :pending_signature
        end
        resources :ligne_devis, only: %i[create destroy], controller: "quote_line_items"
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

      # Catalogue CCAM — nomenclature nationale des actes médicaux.
      # Miroir du turboapp `ActesCcamController` pour le client Flutter HDS.
      resources :actes_ccam, only: %i[index show] do
        collection do
          get :search
          get :categories
          get :specialites
          get :regroupements
        end
      end

      # Tableau de bord analytics (même contrat JSON que turboapp Logosw)
      get "analytics/dashboard", to: "analytics#dashboard"

      # IA consultation (OpenAI) — même contrat que turboapp Logosw
      post "consultation_ai/generate_report", to: "consultation_ai#generate_report"
      post "consultation_ai/generate_colleague_letter", to: "consultation_ai#generate_colleague_letter"
      post "consultation_ai/patient_report_pdf", to: "consultation_ai#patient_report_pdf"

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
