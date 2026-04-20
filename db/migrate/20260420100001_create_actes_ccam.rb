# frozen_string_literal: true

# Table de référence CCAM (Classification Commune des Actes Médicaux).
#
# Structure identique au modèle turboapp `actes_ccam` pour garantir
# la compatibilité avec les imports CSV officiels CCAM.
# La colonne `regroupement` porte la catégorie dentaire (Endodontie,
# Prothèse fixe, Chirurgie dentaire, etc.) utilisée par le panneau
# d'actes de l'application Flutter.
class CreateActesCcam < ActiveRecord::Migration[8.0]
  def change
    create_table :actes_ccam, id: :uuid do |t|
      # Code CCAM officiel (ex. HBLD036)
      t.string :code, null: false

      # Libellé complet de l'acte
      t.string :libelle, null: false

      # Métadonnées CCAM officielles
      t.integer :phase
      t.integer :activite

      # Tarif Sécurité Sociale (base de remboursement)
      t.decimal :tarif_securite_sociale, precision: 10, scale: 2

      # Coefficient NGAP si applicable
      t.decimal :coefficient, precision: 6, scale: 2

      # Spécialité médicale (ex. "Chirurgie dentaire")
      t.string :specialite

      # Catégorie dentaire fonctionnelle pour le panneau actes Flutter.
      # Exemples : "Prothèse fixe", "Endodontie", "Chirurgie dentaire",
      #            "Parodontologie", "Implantologie", "Radiologie",
      #            "Soins conservateurs", "Prothèse amovible"
      t.string :regroupement

      # Modificateurs CCAM possibles (tableau de codes)
      t.text :modificateurs, array: true, default: []

      # Dates de validité de la nomenclature
      t.date :date_effet
      t.date :date_fin

      # Acte actif dans la nomenclature courante
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :actes_ccam, :code,         unique: true
    add_index :actes_ccam, :specialite
    add_index :actes_ccam, :regroupement
    add_index :actes_ccam, :active
    add_index :actes_ccam, %i[regroupement active], name: "idx_actes_ccam_regroupement_active"
  end
end
