# frozen_string_literal: true

module Api
  module V1
    # Catalogue CCAM — nomenclature nationale des actes médicaux.
    #
    # Routes :
    #   GET /api/v1/actes_ccam                  → index (liste paginée)
    #   GET /api/v1/actes_ccam/:id              → show (détail)
    #   GET /api/v1/actes_ccam/search           → search (recherche plein-texte)
    #   GET /api/v1/actes_ccam/categories       → categories (arbre Flutter)
    #   GET /api/v1/actes_ccam/specialites      → specialites (valeurs distinctes)
    #   GET /api/v1/actes_ccam/regroupements    → regroupements (valeurs distinctes)
    #
    # Tous les endpoints sont en lecture seule. Le catalogue est partagé entre
    # toutes les organisations (table de référence nationale).
    class ActesCcamController < Api::V1::BaseController
      before_action :set_acte, only: :show

      # GET /api/v1/actes_ccam
      #
      # Params :
      #   specialite   – filtrer par spécialité
      #   regroupement – filtrer par catégorie dentaire
      #   page         – numéro de page (défaut 1)
      #   per_page     – actes par page (défaut 50, max 200)
      def index
        # Obligatoire pour `verify_policy_scoped` (Api::V1::BaseController) — même si le
        # catalogue CCAM est national, Pundit exige un scope explicite sur l’index.
        scoped = policy_scope(ActeCcam)
        authorize ActeCcam
        service = build_service(base_relation: scoped)

        result = service.call
        render_success({ actes: result[:actes], meta: result[:meta] })
      end

      # GET /api/v1/actes_ccam/:id
      def show
        authorize @acte
        render_success @acte.to_json_api
      end

      # GET /api/v1/actes_ccam/search?q=composite&limit=20
      #
      # Params :
      #   q            – chaîne de recherche (min 2 caractères)
      #   limit        – nombre max de résultats (défaut 20, max 200)
      #   specialite   – filtre optionnel
      #   regroupement – filtre optionnel
      def search
        authorize ActeCcam, :search?
        service = build_service

        results = service.search(params[:q].to_s, limit: params[:limit]&.to_i || 20)
        render_success results
      end

      # GET /api/v1/actes_ccam/categories
      #
      # Retourne l'arbre de catégories dentaires utilisé par le panneau
      # d'actes Flutter (Prothèses / Soins / Chirurgie / Radios), enrichi
      # du nombre d'actes actifs par regroupement.
      def categories
        authorize ActeCcam, :categories?
        service = build_service

        render_success service.categories
      end

      # GET /api/v1/actes_ccam/specialites
      def specialites
        authorize ActeCcam, :specialites?
        render_success build_service.specialites
      end

      # GET /api/v1/actes_ccam/regroupements
      def regroupements
        authorize ActeCcam, :regroupements?
        render_success build_service.regroupements
      end

      private

      def set_acte
        @acte = ActeCcam.active.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error "not_found", "Acte CCAM introuvable", status: :not_found
      end

      def build_service(base_relation: nil)
        Logosw::ActesCcam::CatalogueService.new(
          filters: {
            specialite:   params[:specialite],
            regroupement: params[:regroupement]
          },
          page:     params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || Logosw::ActesCcam::CatalogueService::DEFAULT_PER_PAGE,
          base_relation: base_relation
        )
      end
    end
  end
end
