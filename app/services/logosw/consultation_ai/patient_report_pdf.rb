# frozen_string_literal: true

require "prawn"

module Logosw
  module ConsultationAi
    # PDF « compte rendu patient » — charte visuelle alignée sur les exports Logosw (Prawn + DejaVu).
    class PatientReportPdf
      class Error < StandardError; end

      ACCENT_COLOR = "1e3a5f"
      BODY_COLOR = "2c3e50"
      MUTED_COLOR = "5d6d7e"

      MONTHS_FR = %w[
        janvier février mars avril mai juin juillet août septembre octobre novembre décembre
      ].freeze

      def initialize(patient_name:, report_markdown:, cabinet_label: nil, practitioner_name: nil)
        @patient_name = patient_name.to_s.strip
        @report = report_markdown.to_s
        @cabinet = cabinet_label.to_s.strip.presence
        @practitioner = practitioner_name.to_s.strip.presence
      end

      def render
        pdf = Prawn::Document.new(page_size: "A4", margin: [ 40, 44, 52, 44 ]) do |d|
          register_utf8_font!(d)
          d.fill_color BODY_COLOR
          render_header_band(d)
          render_meta_block(d)
          d.move_down 8
          section_bar(d, "Contenu du compte rendu")
          d.move_down 6
          render_report_lines(d, @report)
          d.move_down 20
          d.fill_color MUTED_COLOR
          d.text <<~TXT.squish, size: 8, align: :justify, leading: 3
            Ce document résume les informations issues de votre consultation, validées par votre praticien avant remise.
            Il ne se substitue pas à un avis médical personnalisé ni à une consultation ultérieure.
          TXT
          d.fill_color BODY_COLOR
        end
        pdf.render
      rescue StandardError => e
        Rails.logger.error("[Logosw::ConsultationAi::PatientReportPdf] #{e.class}: #{e.message}\n#{e.backtrace&.first(6)&.join("\n")}")
        raise Error, e.message
      end

      private

      def register_utf8_font!(pdf)
        dir = Rails.root.join("vendor/fonts")
        normal = dir.join("DejaVuSans.ttf")
        bold = dir.join("DejaVuSans-Bold.ttf")
        unless normal.file?
          raise Error,
                "Police UTF-8 manquante : placez DejaVuSans.ttf dans vendor/fonts/"
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

      def render_header_band(pdf)
        h = 50
        pdf.fill_color ACCENT_COLOR
        pdf.fill_rectangle [ pdf.bounds.left, pdf.bounds.top - h ], pdf.bounds.width, h
        pdf.fill_color "ffffff"
        pdf.text_box "Compte rendu de consultation",
                     at: [ pdf.bounds.left + 12, pdf.bounds.top - 6 ],
                     width: pdf.bounds.width - 24,
                     height: h - 10,
                     size: 16,
                     style: :bold,
                     valign: :center,
                     align: :center
        pdf.fill_color BODY_COLOR
        pdf.move_cursor_to pdf.bounds.top - h - 18
      end

      def render_meta_block(pdf)
        pdf.text "Patient : #{@patient_name}", size: 12, style: :bold
        pdf.move_down 4
        pdf.fill_color MUTED_COLOR
        d = Time.zone.today
        pdf.text "Date : #{d.day} #{MONTHS_FR[d.month - 1]} #{d.year}", size: 10
        pdf.fill_color BODY_COLOR
        if @practitioner.present?
          pdf.move_down 3
          pdf.text "Praticien : #{@practitioner}", size: 10
        end
        return unless @cabinet.present?

        pdf.move_down 2
        pdf.fill_color MUTED_COLOR
        pdf.text "Cabinet : #{@cabinet}", size: 9
        pdf.fill_color BODY_COLOR
      end

      def section_bar(pdf, title)
        h = 20
        y0 = pdf.cursor
        pdf.fill_color ACCENT_COLOR
        pdf.fill_rectangle [ pdf.bounds.left, y0 ], pdf.bounds.width, h
        pdf.fill_color "ffffff"
        pdf.text_box title,
                     at: [ pdf.bounds.left + 8, y0 + 3 ],
                     width: pdf.bounds.width - 16,
                     height: h - 2,
                     size: 10,
                     style: :bold,
                     valign: :center
        pdf.fill_color BODY_COLOR
        pdf.move_down h + 6
      end

      def render_report_lines(pdf, text)
        normalized = text.gsub("\r\n", "\n")
        normalized.each_line do |raw|
          line = raw.rstrip
          if line.blank?
            pdf.move_down 2
            next
          end

          case line
          when /^---+$/ # séparateur Markdown
            pdf.move_down 6
            pdf.stroke_color "bdc3c7"
            pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.right, at: pdf.cursor
            pdf.stroke_color "000000"
            pdf.move_down 10
          when /^## (.+)$/
            section_bar(pdf, Regexp.last_match(1).strip)
          when /^### (.+)$/
            pdf.move_down 2
            pdf.fill_color ACCENT_COLOR
            pdf.text Regexp.last_match(1).strip, size: 11, style: :bold
            pdf.fill_color BODY_COLOR
            pdf.move_down 4
          when /^[-*]\s+(.+)$/
            pdf.text "• #{Regexp.last_match(1).strip}", size: 10, leading: 3.5
          else
            pdf.text format_inline(line), size: 10, leading: 3.5, inline_format: true
          end
        end
      end

      def format_inline(line)
        s = line.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
        s.gsub(/\*\*(.+?)\*\*/, '<b>\1</b>')
      end
    end
  end
end
