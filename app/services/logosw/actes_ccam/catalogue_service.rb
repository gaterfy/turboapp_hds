# frozen_string_literal: true

module Logosw
  module ActesCcam
    # Service applicatif (couche Application DDD) responsable de la consultation
    # du catalogue CCAM.
    #
    # Responsabilités :
    #   - Filtrer et paginer les actes actifs
    #   - Construire l'arbre de catégories dentaires pour le panneau Flutter
    #   - Déléguer la recherche plein-texte
    #
    # Ce service ne modifie aucun état : il est purement en lecture.
    class CatalogueService
      # Nombre max d'actes retournés par défaut (sans pagination explicite)
      DEFAULT_PER_PAGE = 50
      MAX_PER_PAGE     = 200

      # Arbre de catégories dentaires exposé via GET /api/v1/actes_ccam/categories.
      # Chaque catégorie de premier niveau correspond au regroupement Flutter.
      # L'ordre reflète la disposition du panneau Logosw (Prothèses, Soins,
      # Chirurgie, Radios).
      DENTAL_CATEGORIES = [
        {
          id: "protheses",
          label: "Prothèses",
          icon: "diamond_outlined",
          color: "#0284C7",
          subcategories: [
            { id: "prothese_fixe",     label: "Prothèse fixe",                   regroupement: "Prothèse fixe" },
            { id: "prothese_amovible", label: "Prothèse amovible",               regroupement: "Prothèse amovible" },
            { id: "descellement",      label: "Descellement / rescellement",      regroupement: "Descellement" },
            { id: "inlay_onlay",       label: "Inlay-onlay / coping",            regroupement: "Soins conservateurs" },
            { id: "implantologie",     label: "Implants",                         regroupement: "Implantologie" },
            { id: "gouttieres",        label: "Guides, gouttières, contentions",  regroupement: "Orthopédie dento-faciale" }
          ]
        },
        {
          id: "soins",
          label: "Soins",
          icon: "healing_outlined",
          color: "#059669",
          subcategories: [
            { id: "endodontie",          label: "Endodontie",            regroupement: "Endodontie" },
            { id: "prophylaxie",         label: "Prophylaxie",           regroupement: "Parodontologie" },
            { id: "explorations_bilans", label: "Explorations, bilans",  regroupement: "Radiologie" },
            { id: "obturations",         label: "Obturations",           regroupement: "Soins conservateurs" }
          ]
        },
        {
          id: "chirurgie",
          label: "Chirurgie",
          icon: "colorize_outlined",
          color: "#DC2626",
          subcategories: [
            { id: "extractions",      label: "Extractions",              regroupement: "Chirurgie dentaire" },
            { id: "chir_dentaire",    label: "Chirurgie dentaire",       regroupement: "Chirurgie dentaire" },
            { id: "parodontologie",   label: "Parodontologie",           regroupement: "Parodontologie" },
            { id: "chir_maxillo",     label: "Chirurgie maxillo-faciale", regroupement: "Chirurgie maxillo-faciale" }
          ]
        },
        {
          id: "radios",
          label: "Radios",
          icon: "document_scanner_outlined",
          color: "#7C3AED",
          subcategories: [
            { id: "panoramique",     label: "Panoramique",         regroupement: "Radiologie" },
            { id: "retro_alveolaire", label: "Rétro-alvéolaire",  regroupement: "Radiologie" },
            { id: "cbct",            label: "CBCT",                regroupement: "Radiologie" }
          ]
        }
      ].freeze

      # @param filters [Hash] :specialite, :regroupement
      # @param page [Integer]
      # @param per_page [Integer]
      # @param base_relation [ActiveRecord::Relation, nil] racine Pundit (`policy_scope(ActeCcam)`).
      #   Si nil, équivalent à [ActeCcam.all] (catalogue national).
      def initialize(filters: {}, page: 1, per_page: DEFAULT_PER_PAGE, base_relation: nil)
        @filters       = filters.to_h.symbolize_keys
        @page          = [page.to_i, 1].max
        @per_page      = [[per_page.to_i, 1].max, MAX_PER_PAGE].min
        @base_relation = base_relation
      end

      # Retourne les actes paginés selon les filtres.
      #
      # @return [{ actes: Array<Hash>, meta: Hash }]
      def call
        scope = base_scope
        scope = scope.by_specialite(@filters[:specialite])   if @filters[:specialite].present?
        scope = scope.by_regroupement(@filters[:regroupement]) if @filters[:regroupement].present?

        total  = scope.count
        actes  = scope.order(:code)
                      .limit(@per_page)
                      .offset((@page - 1) * @per_page)

        {
          actes: actes.map(&:to_json_api),
          meta:  {
            page:        @page,
            per_page:    @per_page,
            total_count: total,
            total_pages: (total.to_f / @per_page).ceil
          }
        }
      end

      # Recherche plein-texte sur code et libellé.
      #
      # @param query [String]
      # @param limit [Integer]
      # @return [Array<Hash>]
      def search(query, limit: 20)
        return [] if query.to_s.strip.length < 2

        scope = base_scope.search(query)
        scope = scope.by_specialite(@filters[:specialite])    if @filters[:specialite].present?
        scope = scope.by_regroupement(@filters[:regroupement]) if @filters[:regroupement].present?

        scope.order(:code).limit([[limit.to_i, 1].max, MAX_PER_PAGE].min).map(&:to_json_api)
      end

      # Retourne l'arbre de catégories enrichi avec le nombre d'actes disponibles
      # par regroupement (pour affichage dans le panneau Flutter).
      #
      # @return [Array<Hash>]
      def categories
        counts_by_regroupement = ActeCcam.active
                                         .group(:regroupement)
                                         .count

        DENTAL_CATEGORIES.map do |cat|
          {
            id:    cat[:id],
            label: cat[:label],
            icon:  cat[:icon],
            color: cat[:color],
            subcategories: cat[:subcategories].map do |sub|
              {
                id:           sub[:id],
                label:        sub[:label],
                regroupement: sub[:regroupement],
                count:        counts_by_regroupement[sub[:regroupement]] || 0
              }
            end
          }
        end
      end

      # Listes des valeurs distinctes (pour filtres côté client).

      def specialites
        ActeCcam.active.where.not(specialite: [nil, ""]).distinct.pluck(:specialite).sort
      end

      def regroupements
        ActeCcam.active.where.not(regroupement: [nil, ""]).distinct.pluck(:regroupement).sort
      end

      private

      def base_scope
        (@base_relation || ActeCcam.all).active
      end
    end
  end
end
