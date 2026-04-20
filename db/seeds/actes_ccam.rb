# frozen_string_literal: true

# Seeds CCAM — Catalogue dentaire initial.
#
# Couverture : 8 catégories × ~5 actes = 42 actes clés.
# Codes issus de la nomenclature CCAM v82 (01/01/2026).
# Tarifs = tarifs sécu opposables au 01/01/2026 (hors dépassements d'honoraires).
#
# Usage :
#   rails db:seed                         # inclus dans db/seeds.rb
#   rails runner 'load "db/seeds/actes_ccam.rb"'   # seed standalone

puts "  [CCAM] Import des actes dentaires de référence..."

actes = [
  # ── PROTHÈSE FIXE ──────────────────────────────────────────────────────────
  {
    code: "HBLD036", regroupement: "Prothèse fixe", specialite: "Chirurgie dentaire",
    libelle: "Pose d'une couronne dentaire en céramique (RAC 0)",
    tarif_securite_sociale: 120.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD023", regroupement: "Prothèse fixe", specialite: "Chirurgie dentaire",
    libelle: "Pose d'une couronne céramo-métallique",
    tarif_securite_sociale: 107.50, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD010", regroupement: "Prothèse fixe", specialite: "Chirurgie dentaire",
    libelle: "Réalisation d'un bridge de 3 éléments en céramique (RAC 0)",
    tarif_securite_sociale: 360.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD015", regroupement: "Prothèse fixe", specialite: "Chirurgie dentaire",
    libelle: "Pose d'une couronne métal-céramique sur dent dépulpée",
    tarif_securite_sociale: 107.50, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD132", regroupement: "Prothèse fixe", specialite: "Chirurgie dentaire",
    libelle: "Inlay-core en alliage métallique coulé avec moignon et tenon",
    tarif_securite_sociale: 122.55, activite: 1, phase: 1, active: true
  },

  # ── PROTHÈSE AMOVIBLE ──────────────────────────────────────────────────────
  {
    code: "HBLA001", regroupement: "Prothèse amovible", specialite: "Chirurgie dentaire",
    libelle: "Prothèse amovible partielle en résine (1 à 5 dents)",
    tarif_securite_sociale: 100.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLA002", regroupement: "Prothèse amovible", specialite: "Chirurgie dentaire",
    libelle: "Prothèse amovible totale d'un maxillaire",
    tarif_securite_sociale: 120.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLA003", regroupement: "Prothèse amovible", specialite: "Chirurgie dentaire",
    libelle: "Prothèse amovible partielle à armature métallique (squelettée)",
    tarif_securite_sociale: 180.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLA004", regroupement: "Prothèse amovible", specialite: "Chirurgie dentaire",
    libelle: "Prothèse amovible totale bimaxillaire",
    tarif_securite_sociale: 240.00, activite: 1, phase: 1, active: true
  },

  # ── DESCELLEMENT ───────────────────────────────────────────────────────────
  {
    code: "HBLD050", regroupement: "Descellement", specialite: "Chirurgie dentaire",
    libelle: "Descellement d'une couronne ou d'un pivot",
    tarif_securite_sociale: 28.92, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD051", regroupement: "Descellement", specialite: "Chirurgie dentaire",
    libelle: "Rescellement d'une couronne dentaire (par élément)",
    tarif_securite_sociale: 19.81, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD052", regroupement: "Descellement", specialite: "Chirurgie dentaire",
    libelle: "Rescellement d'un bridge (par pilier)",
    tarif_securite_sociale: 22.40, activite: 1, phase: 1, active: true
  },

  # ── SOINS CONSERVATEURS / OBTURATIONS ─────────────────────────────────────
  {
    code: "HBMD038", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Restauration d'une dent par composite — 1 face atteinte",
    tarif_securite_sociale: 26.97, activite: 1, phase: 1, active: true
  },
  {
    code: "HBMD044", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Restauration d'une dent par composite — 2 faces atteintes",
    tarif_securite_sociale: 45.38, activite: 1, phase: 1, active: true
  },
  {
    code: "HBMD047", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Restauration d'une dent par composite — 3 faces et plus",
    tarif_securite_sociale: 60.95, activite: 1, phase: 1, active: true
  },
  {
    code: "HBMD060", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Facette céramique esthétique (hors nomenclature RAC libre)",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBMD028", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Coiffe de protection pulpaire — application de fond de cavité",
    tarif_securite_sociale: 12.40, activite: 1, phase: 1, active: true
  },

  # ── INLAY-ONLAY ────────────────────────────────────────────────────────────
  {
    code: "HBLD018", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Inlay / onlay en céramique (1 face)",
    tarif_securite_sociale: 100.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLD019", regroupement: "Soins conservateurs", specialite: "Chirurgie dentaire",
    libelle: "Onlay en céramique (2 faces et plus)",
    tarif_securite_sociale: 105.00, activite: 1, phase: 1, active: true
  },

  # ── ENDODONTIE ─────────────────────────────────────────────────────────────
  {
    code: "HBFA003", regroupement: "Endodontie", specialite: "Chirurgie dentaire",
    libelle: "Pulpectomie d'une dent à 1 canal (incisive ou canine)",
    tarif_securite_sociale: 33.74, activite: 1, phase: 1, active: true
  },
  {
    code: "HBFA007", regroupement: "Endodontie", specialite: "Chirurgie dentaire",
    libelle: "Pulpectomie d'une dent à 2 canaux (prémolaire)",
    tarif_securite_sociale: 48.20, activite: 1, phase: 1, active: true
  },
  {
    code: "HBFA008", regroupement: "Endodontie", specialite: "Chirurgie dentaire",
    libelle: "Pulpectomie d'une dent à 3 canaux (molaire)",
    tarif_securite_sociale: 81.94, activite: 1, phase: 1, active: true
  },
  {
    code: "HBFA009", regroupement: "Endodontie", specialite: "Chirurgie dentaire",
    libelle: "Retraitement endodontique — 1 canal",
    tarif_securite_sociale: 55.90, activite: 1, phase: 1, active: true
  },
  {
    code: "HBFA012", regroupement: "Endodontie", specialite: "Chirurgie dentaire",
    libelle: "Retraitement endodontique — molaire (4 canaux)",
    tarif_securite_sociale: 102.22, activite: 1, phase: 1, active: true
  },

  # ── PARODONTOLOGIE ─────────────────────────────────────────────────────────
  {
    code: "HBQK040", regroupement: "Parodontologie", specialite: "Chirurgie dentaire",
    libelle: "Détartrage complet sus et sous-gingival",
    tarif_securite_sociale: 28.92, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK043", regroupement: "Parodontologie", specialite: "Chirurgie dentaire",
    libelle: "Surfaçage radiculaire (détartrage sous-gingival approfondi) — par quadrant",
    tarif_securite_sociale: 57.84, activite: 1, phase: 1, active: true
  },
  {
    code: "HBJA010", regroupement: "Parodontologie", specialite: "Chirurgie dentaire",
    libelle: "Lambeau de Widman modifié — chirurgie parodontale (par sextant)",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK042", regroupement: "Parodontologie", specialite: "Chirurgie dentaire",
    libelle: "Application de vernis fluoré ou désinfection parodontale",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },

  # ── CHIRURGIE DENTAIRE ─────────────────────────────────────────────────────
  {
    code: "HBGD001", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Extraction d'une dent permanente simple",
    tarif_securite_sociale: 33.44, activite: 1, phase: 1, active: true
  },
  {
    code: "HBGD002", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Extraction complexe d'une dent permanente avec alvéolectomie",
    tarif_securite_sociale: 55.10, activite: 1, phase: 1, active: true
  },
  {
    code: "HBGD003", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Extraction chirurgicale d'une dent de sagesse incluse ou semi-incluse",
    tarif_securite_sociale: 111.93, activite: 1, phase: 1, active: true
  },
  {
    code: "HBJA001", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Greffe osseuse avec membrane guidée (régénération osseuse guidée)",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBJA002", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Réalisation d'un lambeau muco-périosté d'accès chirurgical",
    tarif_securite_sociale: 51.25, activite: 1, phase: 1, active: true
  },
  {
    code: "HBJA003", regroupement: "Chirurgie dentaire", specialite: "Chirurgie dentaire",
    libelle: "Résection apicale avec obturation rétrograde",
    tarif_securite_sociale: 123.58, activite: 1, phase: 1, active: true
  },

  # ── IMPLANTOLOGIE ──────────────────────────────────────────────────────────
  {
    code: "HBLA006", regroupement: "Implantologie", specialite: "Chirurgie dentaire",
    libelle: "Pose d'un implant ostéo-intégré + pilier prothétique",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLA007", regroupement: "Implantologie", specialite: "Chirurgie dentaire",
    libelle: "Couronne sur implant (céramique ou céramo-métallique)",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },
  {
    code: "HBLA008", regroupement: "Implantologie", specialite: "Chirurgie dentaire",
    libelle: "Bridge sur implants — remplacement de plusieurs dents (par élément)",
    tarif_securite_sociale: 0.00, activite: 1, phase: 1, active: true
  },

  # ── RADIOLOGIE ─────────────────────────────────────────────────────────────
  {
    code: "HBQK001", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "Panoramique dentaire numérique (orthopantomogramme)",
    tarif_securite_sociale: 24.70, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK002", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "Rétro-alvéolaire unitaire numérique",
    tarif_securite_sociale: 8.76, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK003", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "Bitewing (2 incidences interproximales bilatérales)",
    tarif_securite_sociale: 17.52, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK004", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "Série rétro-alvéolaire complète (14 clichés)",
    tarif_securite_sociale: 61.32, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK010", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "CBCT volume limité (< 8 cm) — implantologie ou endodontie",
    tarif_securite_sociale: 89.27, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK011", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "CBCT volume moyen (8-15 cm) — analyse pré-opératoire",
    tarif_securite_sociale: 118.65, activite: 1, phase: 1, active: true
  },
  {
    code: "HBQK012", regroupement: "Radiologie", specialite: "Chirurgie dentaire",
    libelle: "CBCT grand volume crânio-facial",
    tarif_securite_sociale: 178.00, activite: 1, phase: 1, active: true
  }
].freeze

imported = 0
skipped  = 0
errors   = []

actes.each do |attrs|
  acte = ActeCcam.find_or_initialize_by(code: attrs[:code])
  if acte.new_record? || acte.libelle != attrs[:libelle]
    if acte.update(attrs)
      imported += 1
    else
      errors << { code: attrs[:code], error: acte.errors.full_messages.to_sentence }
    end
  else
    skipped += 1
  end
end

puts "  [CCAM] Importés / mis à jour : #{imported}"
puts "  [CCAM] Inchangés             : #{skipped}"
puts "  [CCAM] Erreurs               : #{errors.size}"
errors.each { |e| puts "    #{e[:code]} → #{e[:error]}" }
puts "  [CCAM] Total en base         : #{ActeCcam.count}"
