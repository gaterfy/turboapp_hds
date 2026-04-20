# frozen_string_literal: true

# Table de référence CCAM (Classification Commune des Actes Médicaux).
#
# Couche domaine : représente un acte médical normalisé, identifié
# par un code unique, avec ses métadonnées tarifaires officielles.
#
# Les tarifs stockés ici sont les tarifs Sécurité sociale (opposables).
# Les honoraires réels sont fixés au moment de l'émission d'un devis
# (QuoteLineItem#unit_fee) et sont indépendants de ce modèle.
#
# La colonne `regroupement` porte la catégorie dentaire fonctionnelle
# utilisée par le panneau d'actes Flutter :
#   "Prothèse fixe", "Prothèse amovible", "Endodontie",
#   "Chirurgie dentaire", "Parodontologie", "Implantologie",
#   "Radiologie", "Soins conservateurs"
class ActeCcam < ApplicationRecord
  self.table_name = "actes_ccam"

  # ── Validations ────────────────────────────────────────────────────────────

  validates :code,    presence: true, uniqueness: { case_sensitive: false }
  validates :libelle, presence: true

  # ── Scopes généraux ────────────────────────────────────────────────────────

  scope :active,           -> { where(active: true) }
  scope :by_specialite,    ->(spec) { where(specialite: spec) }
  scope :by_regroupement,  ->(reg)  { where(regroupement: reg) }

  scope :search, lambda { |query|
    sanitized = "%#{sanitize_sql_like(query)}%"
    where("code ILIKE ? OR libelle ILIKE ?", sanitized, sanitized)
  }

  # ── Scopes catégories dentaires (Logosw) ──────────────────────────────────

  scope :prothese_fixe,     -> { active.by_regroupement("Prothèse fixe") }
  scope :prothese_amovible, -> { active.by_regroupement("Prothèse amovible") }
  scope :endodontie,        -> { active.by_regroupement("Endodontie") }
  scope :chirurgie,         -> { active.by_regroupement("Chirurgie dentaire") }
  scope :parodontologie,    -> { active.by_regroupement("Parodontologie") }
  scope :implantologie,     -> { active.by_regroupement("Implantologie") }
  scope :radiologie,        -> { active.by_regroupement("Radiologie") }
  scope :soins_conservateurs, -> { active.by_regroupement("Soins conservateurs") }

  # ── Prédicats ──────────────────────────────────────────────────────────────

  def expired?
    date_fin.present? && date_fin < Date.current
  end

  def rac_zero?
    tarif_securite_sociale.present? && tarif_securite_sociale > 0
  end

  # ── Sérialisation API ──────────────────────────────────────────────────────

  # Contrat JSON consommé par Flutter ActeCcamDto.fromJson.
  def to_json_api
    {
      id:                     id,
      code:                   code,
      libelle:                libelle,
      phase:                  phase,
      activite:               activite,
      tarif_securite_sociale: tarif_securite_sociale&.to_f,
      coefficient:            coefficient&.to_f,
      specialite:             specialite,
      regroupement:           regroupement,
      modificateurs:          modificateurs || [],
      date_effet:             date_effet,
      date_fin:               date_fin,
      active:                 active
    }
  end
end
