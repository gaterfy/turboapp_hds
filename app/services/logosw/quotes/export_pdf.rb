# frozen_string_literal: true

# Port réglementaire du PDF turboapp `Logosw::Devises::ExportPdf`
# (convention nationale, tableaux, mentions légales, pages indissociables).
#
# Données HDS : [Quote], [QuoteLineItem], [PatientRecord], [Patient], [Organization], [Practitioner].
require "prawn"
require "prawn/table"

module Logosw
  module Quotes
    class ExportPdf
      class Error < StandardError; end

      STATUT_LABELS = {
        "draft" => "Brouillon",
        "sent" => "Envoyé au patient",
        "signed" => "Signé",
        "rejected" => "Refusé",
        "expired" => "Expiré"
      }.freeze

      TITLE = "DEVIS POUR LES TRAITEMENTS ET ACTES BUCCO-DENTAIRES FAISANT L’OBJET D’UNE ENTENTE DIRECTE"
      SUBTITLE = "conformément aux dispositions de la convention nationale des chirurgiens-dentistes (publiée au JO du 25 août 2018)"
      LEGAL_NOTICE = <<~TXT.squish
        Ce devis est la propriété du patient ou de son représentant légal. La communication de ce document à un tiers se fait sous sa seule responsabilité.
        Ce devis est informatif, les montants des honoraires et prises en charge sont définis selon les droits effectifs à la date de réalisation de l’acte.
        Les soins à tarifs opposables ne sont pas compris dans ce devis.
      TXT

      LEGENDE_MATERIAUX = <<~TXT.squish
        Légende explicative du devis : 1 Alliage précieux NF EN ISO 22674 2016 2 Alliage non précieux ISO 22674 2016 3 Céramo-céramique NF EN ISO 9693 2016
        4 Céramique céramométallique NF EN ISO 6872 2015 5 Polymères de base NF EN ISO 20795:1:2013 6 Dents artificielles NF EN ISO 22112 2017
      TXT

      LEGENDE_FOOTNOTES = <<~TXT.squish
        * HN = Hors Nomenclature. ** Matériaux et normes : codes 1 à 6 ci-dessus.
        *** Les montants remboursés et non remboursés du régime obligatoire sont informatifs ; la prise en charge définitive est définie à la date de réalisation de l’acte.
        **** Paniers : 1 — 100 % Santé soumis à honoraires limites de facturation sans reste à charge, si le patient bénéficie d’un contrat dit responsable.
        2 — Modéré soumis à honoraires limites de facturation selon le contrat du patient. 3 — Libre honoraires libres selon le contrat du patient.
        Panier Complémentaire santé solidaire 4 — Complémentaire santé solidaire soumis à honoraires limites de facturation pour les assurés bénéficiaires de la Complémentaire Santé Solidaire.
      TXT

      INFO_ALTERNATIVES = <<~TXT.squish
        Information alternative thérapeutique en cas de reste à charge éventuel, une information sur des alternatives thérapeutiques 100 % Santé ou,
        à défaut, à entente directe modérée est donnée par le praticien. Sur demande du patient, elle peut donner lieu à une nouvelle proposition de plan de traitement complet, dans un devis distinct.
        Le patient ou son représentant légal reconnaît avoir eu la possibilité du choix de son traitement.
      TXT

      MENTION_TRACABILITE_DM = <<~TXT.squish
        À l’issue du traitement, il vous sera remis une fiche de traçabilité et la déclaration de conformité du dispositif médical
        (document rempli par le fabricant ou son mandataire et sous sa seule responsabilité).
      TXT

      def initialize(quote:)
        @quote = quote
      end

      def call
        dossier = @quote.patient_record
        patient = dossier.patient
        practitioner = @quote.practitioner
        organization = @quote.organization
        cabinet_address = organization_cabinet_address(organization)

        lignes = @quote.line_items.order(:position).to_a
        sans_rac, modere, libre = partition_lignes(lignes)

        pdf = Prawn::Document.new(page_size: "A4", margin: [ 44, 48, 56, 48 ]) do |d|
          register_utf8_font!(d)
          d.fill_color "2c3e50"

          render_title_block(d)
          render_praticien_block(d, practitioner, organization, cabinet_address)
          render_dates_and_placeholder(d)
          render_patient_block(d, patient)
          render_bloc_complementaire(d)
          render_fabrication_dm(d)
          d.move_down 10
          d.fill_color "34495e"
          d.text MENTION_TRACABILITE_DM, size: 8, leading: 2
          d.fill_color "2c3e50"

          d.move_down 14
          section_bar(d, "Légende — matériaux, paniers et notes")
          d.move_down 6
          d.text LEGENDE_MATERIAUX, size: 7, leading: 2
          d.move_down 4
          d.text LEGENDE_FOOTNOTES, size: 7, leading: 2

          d.move_down 12
          section_bar(d, "Traitement proposé — description précise et détaillée des actes")
          d.move_down 8
          render_actes_table(d, "Synthèse — tous les actes envisagés", lignes, include_panier: true)

          d.move_down 10
          section_bar(d, "Acte sans reste à charge (100 % Santé)")
          d.move_down 6
          render_actes_table(d, nil, sans_rac, include_panier: false)

          d.move_down 10
          section_bar(d, "Acte en reste à charge modéré")
          d.move_down 6
          render_actes_table(d, nil, modere, include_panier: false)

          d.move_down 10
          section_bar(d, "Acte en reste à charge libre")
          d.move_down 6
          render_actes_table(d, nil, libre, include_panier: false)

          d.move_down 12
          d.fill_color "34495e"
          d.text INFO_ALTERNATIVES, size: 8, leading: 3
          d.fill_color "2c3e50"

          if @quote.notes.present?
            d.move_down 12
            section_bar(d, "Observations du praticien")
            d.move_down 6
            d.text @quote.notes.to_s, size: 9, leading: 3
          end

          d.move_down 20
          render_signatures(d)

          d.fill_color "888888"
          d.move_down 16
          d.text "Statut du devis (interne) : #{STATUT_LABELS[@quote.status] || @quote.status} — #{@quote.quote_number}", size: 7
        end

        total = pdf.page_count
        pdf.go_to_page(1)
        overlay_page_indissociables(pdf, total)
        pdf.number_pages(
          "Page <page> / <total>",
          page_filter: ->(_n) { true },
          at: [ pdf.bounds.right - 90, 16 ],
          align: :right,
          size: 9,
          color: "555555"
        )
        pdf.render
      rescue StandardError => e
        Rails.logger.error("[Logosw::Quotes::ExportPdf] #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
        raise Error, e.message
      end

      private

      # Adresse cabinet : `organization.settings` JSON (clés `address` ou `cabinet_address`), Hash ou String.
      def organization_cabinet_address(organization)
        settings = organization&.settings
        settings = {} unless settings.is_a?(Hash)
        raw = settings["address"] || settings["cabinet_address"] || settings[:address] || settings[:cabinet_address]
        case raw
        when Hash
          h = raw.stringify_keys
          parts = [
            h["street1"],
            h["street2"],
            "#{h['postal_code']} #{h['city']}".strip
          ].compact_blank
          parts.join(", ").presence
        when String
          raw.strip.presence
        end
      end

      def register_utf8_font!(pdf)
        dir = Rails.root.join("vendor/fonts")
        normal = dir.join("DejaVuSans.ttf")
        bold = dir.join("DejaVuSans-Bold.ttf")
        unless normal.file?
          raise Error,
                "Police UTF-8 manquante : placez DejaVuSans.ttf dans vendor/fonts/ (paquet fonts-dejavu-core)."
        end

        pdf.font_families.update(
          "DejaVuSans" => {
            normal: normal.to_s,
            bold: bold.file? ? bold.to_s : normal.to_s,
            italic: normal.to_s,
            bold_italic: bold.file? ? bold.to_s : normal.to_s
          }
        )
        pdf.font "DejaVuSans"
      end

      def overlay_page_indissociables(pdf, total)
        pdf.go_to_page(1)
        y = @indissoc_stamp_y || (pdf.bounds.top - 160)
        pdf.text_box(
          "Ce devis contient #{total} page#{'s' if total > 1} indissociables.",
          at: [ pdf.bounds.left, y ],
          width: pdf.bounds.width,
          height: 20,
          size: 9,
          style: :italic,
          valign: :center
        )
      end

      def section_bar(pdf, title)
        h = 22
        y0 = pdf.cursor
        pdf.fill_color "1e3a5f"
        pdf.fill_rectangle [ pdf.bounds.left, y0 ], pdf.bounds.width, h
        pdf.fill_color "ffffff"
        pdf.text_box title,
                     at: [ pdf.bounds.left + 8, y0 + 4 ],
                     width: pdf.bounds.width - 16,
                     height: h - 2,
                     size: 10,
                     style: :bold,
                     valign: :center
        pdf.fill_color "2c3e50"
        pdf.move_down h + 6
      end

      def render_title_block(pdf)
        pdf.text TITLE, size: 10, style: :bold, align: :center, leading: 3
        pdf.move_down 4
        pdf.text SUBTITLE, size: 8, align: :center, leading: 2
        pdf.move_down 8
        pdf.fill_color "5d6d7e"
        pdf.text LEGAL_NOTICE, size: 8, align: :justify, leading: 3
        pdf.fill_color "2c3e50"
        pdf.move_down 14
      end

      def render_praticien_block(pdf, practitioner, organization, cabinet_address)
        section_bar(pdf, "Identification du chirurgien-dentiste traitant")
        nom = practitioner ? "#{practitioner.first_name} #{practitioner.last_name}" : "—"
        pdf.text "Nom Prénom : #{nom}", size: 10
        pdf.move_down 4
        pdf.text "Identifiant du praticien RPPS : ………………………………    N° Adeli : " \
                 "#{practitioner&.license_number.presence || '………………………………'}    ou N° de l’établissement (FINESS) : ………………………………",
                 size: 9, leading: 3
        pdf.move_down 6
        raison = organization&.name.presence || "Cabinet dentaire"
        adr = cabinet_address.presence || "……………………………………………………………………………………"
        pdf.text "Raison sociale et adresse : #{raison}", size: 9
        pdf.text adr, size: 9, leading: 3
        pdf.move_down 10
      end

      def render_dates_and_placeholder(pdf)
        pdf.text "Date du devis : #{fmt_date(@quote.created_at)}", size: 10, style: :bold
        vu = @quote.valid_until.present? ? fmt_date(@quote.valid_until) : "— / — / —"
        pdf.text "Valable jusqu’au (sous réserve de modification réglementaire) : #{vu}", size: 10
        pdf.move_down 8
        @indissoc_stamp_y = pdf.cursor
        pdf.move_down 22
      end

      def render_patient_block(pdf, patient)
        pdf.text "Description du traitement proposé :", size: 10, style: :bold
        pdf.move_down 10
        section_bar(pdf, "Identification du patient")
        pdf.text "Nom et prénom : #{patient.full_name}     Date de naissance : #{fmt_date(patient.birth_date)}", size: 10
        pdf.move_down 4
        nss = patient.social_security_number.presence || "……………………………………………………"
        pdf.text "N° de Sécurité sociale du patient : #{nss}", size: 10
        pdf.move_down 10
      end

      def render_bloc_complementaire(pdf)
        pdf.stroke_color "bdc3c7"
        pdf.line_width 0.5
        pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: pdf.cursor
        pdf.move_down 10
        y0 = pdf.cursor
        pdf.bounding_box([ pdf.bounds.left, y0 ], width: pdf.bounds.width) do
          pdf.text "À remplir par l’assuré si celui-ci souhaite envoyer ce devis à son organisme complémentaire " \
                   "pour connaître son éventuel reste à charge selon son contrat :",
                   size: 9, style: :bold
          pdf.move_down 8
          pdf.text "Nom de l’organisme complémentaire : ……………………………………………………………………………………", size: 9
          pdf.text "N° de contrat ou d’adhérent : ……………………………………………………………………………………", size: 9
          pdf.text "Référence dossier (à remplir par l’organisme complémentaire) : ………………………………………", size: 9
        end
        pdf.move_down 12
        pdf.fill_color "2c3e50"
      end

      def render_fabrication_dm(pdf)
        pdf.text "Lieu de fabrication du dispositif médical :", size: 9, style: :bold
        pdf.move_down 4
        pdf.text "☐ au sein de l’Union Européenne    ☐ hors Union Européenne", size: 9
        pdf.move_down 4
        pdf.text "☐ sans sous-traitance du fabricant    ☐ avec une partie de la réalisation du fabricant sous-traitée : " \
                 "☐ au sein de l’Union Européenne    ☐ hors Union Européenne",
                 size: 8, leading: 3
      end

      def partition_lignes(lignes)
        sans_rac = []
        modere = []
        libre = []
        lignes.each do |l|
          rac = ligne_rac_total(l)
          remb = ligne_montant_rembourse_total(l)
          if rac <= 0.005
            sans_rac << l
          elsif remb > 0.005
            modere << l
          else
            libre << l
          end
        end
        [ sans_rac, modere, libre ]
      end

      # Montants par ligne (HDS : bases / remboursements stockés au niveau ligne, honoraires = unit_fee × quantité).
      def ligne_honoraires_total(l)
        l.unit_fee.to_d * l.quantity
      end

      def ligne_base_total(l)
        l.reimbursement_base.to_d
      end

      def ligne_montant_rembourse_total(l)
        l.reimbursement_amount.to_d
      end

      def ligne_rac_total(l)
        ligne_honoraires_total(l) - ligne_montant_rembourse_total(l)
      end

      def ligne_non_remb_amo_total(l)
        [ ligne_base_total(l) - ligne_montant_rembourse_total(l), 0 ].max
      end

      def cotation_cell(l)
        l.procedure_code.presence || "—"
      end

      def panier_cell(_l)
        "—"
      end

      def materiaux_cell(_l)
        "—"
      end

      def render_actes_table(pdf, subtitle, lignes, include_panier:)
        pdf.text subtitle, size: 9, style: :bold if subtitle.present?
        pdf.move_down 4 if subtitle.present?

        headers = if include_panier
                    [
                      "N°\ntrt.",
                      "N° dent\nou loc.",
                      "Cotation\nCCAM / NGAP / HN",
                      "Nature de\nl’acte",
                      "Matériaux\n(**)",
                      "Panier\n(****)",
                      "Honoraires\nlimites de\nfacturation",
                      "Honoraires pratiqués\n(dont prix de vente\nDM)",
                      "Base remb.\nSS",
                      "Montant\nremb. SS\n(***)",
                      "Montant non\nremb. SS",
                      "RAC",
                      "Réalisé par\nvotre\npraticien"
                    ]
                  else
                    [
                      "N°\ntrt.",
                      "N° dent\nou loc.",
                      "Cotation\nCCAM / NGAP / HN",
                      "Nature de\nl’acte",
                      "Matériaux\n(**)",
                      "Honoraires\nlimites de\nfacturation",
                      "Honoraires pratiqués\n(dont prix de vente\nDM)",
                      "Base remb.\nSS",
                      "Montant\nremb. SS\n(***)",
                      "Montant non\nremb. SS",
                      "RAC",
                      "Réalisé par\nvotre\npraticien"
                    ]
                  end

        data = [ headers ]

        if lignes.empty?
          empty_row = (include_panier ? Array.new(13, "—") : Array.new(12, "—"))
          empty_row[3] = "Aucun acte dans cette section"
          data << empty_row
        else
          lignes.each_with_index do |l, i|
            h_tot = ligne_honoraires_total(l)
            base_tot = ligne_base_total(l)
            remb_tot = ligne_montant_rembourse_total(l)
            non_remb = ligne_non_remb_amo_total(l)
            rac = ligne_rac_total(l)
            hon_prat = "#{format_eur(h_tot)}\n(dont DM : —)"
            row = [
              (i + 1).to_s,
              l.tooth_location.presence || "—",
              cotation_cell(l),
              l.label.to_s.truncate(120),
              materiaux_cell(l)
            ]
            row << panier_cell(l) if include_panier
            row += [
              format_eur(base_tot),
              hon_prat,
              format_eur(base_tot),
              format_eur(remb_tot),
              format_eur(non_remb),
              format_eur(rac),
              "☐"
            ]
            data << row
          end
        end

        totals = totals_for(lignes)
        total_row = if include_panier
                      [
                        "TOTAL €",
                        "", "", "", "", "",
                        format_eur(totals[:hon_lim]),
                        format_eur(totals[:hon_prat]),
                        format_eur(totals[:base]),
                        format_eur(totals[:remb]),
                        format_eur(totals[:non_remb]),
                        format_eur(totals[:rac]),
                        ""
                      ]
                    else
                      [
                        "TOTAL €",
                        "", "", "", "",
                        format_eur(totals[:hon_lim]),
                        format_eur(totals[:hon_prat]),
                        format_eur(totals[:base]),
                        format_eur(totals[:remb]),
                        format_eur(totals[:non_remb]),
                        format_eur(totals[:rac]),
                        ""
                      ]
                    end
        data << total_row

        col_widths = if include_panier
                       [ 20, 34, 40, 70, 24, 22, 42, 46, 36, 36, 36, 32, 45 ]
                     else
                       [ 22, 36, 42, 88, 26, 44, 48, 36, 36, 36, 32, 45 ]
                     end

        pdf.table(data, header: true, column_widths: col_widths, cell_style: { size: 6, padding: [ 3, 3 ], border_color: "bdc3c7", valign: :center }) do |t|
          t.row(0).background_color = "ecf0f1"
          t.row(0).font_style = :bold
          t.rows(-1).background_color = "d5d8dc"
          t.rows(-1).font_style = :bold
        end
      end

      def totals_for(lignes)
        hon_lim = lignes.sum { |l| ligne_base_total(l) }
        hon_prat = lignes.sum { |l| ligne_honoraires_total(l) }
        base = lignes.sum { |l| ligne_base_total(l) }
        remb = lignes.sum { |l| ligne_montant_rembourse_total(l) }
        non_remb = lignes.sum { |l| ligne_non_remb_amo_total(l) }
        rac = lignes.sum { |l| ligne_rac_total(l) }
        { hon_lim: hon_lim, hon_prat: hon_prat, base: base, remb: remb, non_remb: non_remb, rac: rac }
      end

      def render_signatures(pdf)
        pdf.move_down 8
        w = (pdf.bounds.width - 16) / 2
        y = pdf.cursor
        pdf.bounding_box([ pdf.bounds.left, y ], width: w) do
          pdf.stroke_color "95a5a6"
          pdf.stroke_horizontal_rule
          pdf.move_down 6
          pdf.text "Date et signature du patient ou du (ou des) responsable(s) légal (légaux)", size: 9, style: :bold
          pdf.move_down 36
        end
        pdf.bounding_box([ pdf.bounds.left + w + 16, y ], width: w) do
          pdf.stroke_color "95a5a6"
          pdf.stroke_horizontal_rule
          pdf.move_down 6
          pdf.text "Signature du Chirurgien-dentiste", size: 9, style: :bold
          pdf.move_down 36
        end
      end

      def format_eur(amount)
        format("%.2f €", amount.to_f)
      end

      def fmt_date(value)
        return "— / — / —" if value.blank?

        value.to_date.strftime("%d/%m/%Y")
      end
    end
  end
end
