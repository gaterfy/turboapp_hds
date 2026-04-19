# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Logosw
  module ConsultationAi
    class GenerateReportService
      SYSTEM_PROMPT = <<~PROMPT
        Tu es un assistant médical IA spécialisé en chirurgie dentaire.
        Tu aides les praticiens à structurer les comptes rendus de consultation et les courriers de confraternité.

        RÈGLES STRICTES :
        - Utilise un langage médical professionnel et précis.
        - Ne diagnostique jamais : tu structures les observations du praticien.
        - Respecte la nomenclature FDI pour les dents (11-48).
        - Propose des actes que tu penses important si nécessaire.
        - Inclus toujours : motif, examen clinique, hypothèses/diagnostic praticien, plan proposé, conseils.
        - Le compte rendu patient doit être compréhensible par un non-professionnel.
        - Le courrier confrère doit être formel et utiliser le vocabulaire spécialisé.
        - Réponds UNIQUEMENT en JSON valide, sans bloc markdown.
      PROMPT

      OPENAI_URL = "https://api.openai.com/v1/chat/completions"

      def initialize
        @api_key = ENV.fetch("OPENAI_API_KEY", "")
        raise "OPENAI_API_KEY non configurée" if @api_key.blank?
      end

      def call(transcript_lines:, patient_name:, colleague_kind: "prosthetist")
        raise ArgumentError, "Transcription vide" if transcript_lines.blank?

        transcript_text = transcript_lines.join("\n")
        user_prompt = build_user_prompt(transcript_text, patient_name, colleague_kind)

        Rails.logger.info "[ConsultationAI] Appel OpenAI — #{transcript_lines.size} lignes, patient=#{patient_name}"

        body = {
          model: "gpt-4o-mini",
          temperature: 0.3,
          max_tokens: 2000,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: user_prompt }
          ]
        }

        data = openai_request(body)
        content = data.dig("choices", 0, "message", "content")
        Rails.logger.info "[ConsultationAI] Réponse reçue: #{content&.truncate(200)}"
        parse_json_report(content)
      rescue StandardError => e
        Rails.logger.error "[ConsultationAI] Error: #{e.class} — #{e.message}"
        Rails.logger.error e.backtrace&.first(5)&.join("\n")
        fallback_report(transcript_lines, patient_name, colleague_kind)
      end

      def generate_colleague_letter(transcript_lines:, patient_name:, colleague_kind:)
        raise ArgumentError, "Transcription vide" if transcript_lines.blank?

        transcript_text = transcript_lines.join("\n")

        user_prompt = <<~PROMPT
          À partir de cette transcription de consultation dentaire, génère un courrier de confraternité
          destiné à un #{colleague_label(colleague_kind)}.

          Patient : #{patient_name}
          Transcription :
          #{transcript_text}

          Réponds en JSON : {"subject": "...", "body": "..."}
          Le body doit commencer par "Bonjour," et finir par "Cordialement,"
        PROMPT

        body = {
          model: "gpt-4o-mini",
          temperature: 0.3,
          max_tokens: 1000,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: user_prompt }
          ]
        }

        data = openai_request(body)
        content = data.dig("choices", 0, "message", "content")
        JSON.parse(content).slice("subject", "body")
      rescue StandardError => e
        Rails.logger.error "[ConsultationAI] Colleague letter error: #{e.class} — #{e.message}"
        fallback_colleague_letter(colleague_kind)
      end

      private

      def configure_openai_ssl(http)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        store = OpenSSL::X509::Store.new
        store.set_default_paths
        if (ca = ENV["SSL_CERT_FILE"]).present? && File.file?(ca)
          store.add_file(ca)
        end
        http.cert_store = store
        http.verify_callback = lambda do |preverify_ok, cert_store_ctx|
          next true if preverify_ok

          cert_store_ctx.error == OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
        end
      end

      def openai_request(body)
        uri = URI(OPENAI_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        configure_openai_ssl(http)
        http.open_timeout = 15
        http.read_timeout = 120

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}"
        request.body = body.to_json

        response = http.request(request)

        raise "OpenAI HTTP #{response.code}: #{response.body&.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end

      def build_user_prompt(transcript_text, patient_name, colleague_kind)
        <<~PROMPT
          Voici la transcription d'une consultation dentaire.
          Patient : #{patient_name}

          TRANSCRIPTION :
          #{transcript_text}

          Génère un JSON avec exactement ces clés :
          {
            "patient_report": "le compte rendu structuré en Markdown pour le patient",
            "colleague_subject": "l'objet du courrier confrère (#{colleague_label(colleague_kind)})",
            "colleague_body": "le corps du courrier de confraternité"
          }

          Le patient_report doit contenir : ## Compte rendu de consultation, ### Motif, ### Examen clinique, ### Diagnostic & conduite, ### Plan de suivi, ### Conseils.
          Ajoute la date du jour et une mention "validé par votre praticien avant envoi" en bas.
        PROMPT
      end

      def parse_json_report(content)
        data = JSON.parse(content)
        {
          patient_report: data["patient_report"].to_s,
          colleague_subject: data["colleague_subject"].to_s,
          colleague_body: data["colleague_body"].to_s
        }
      rescue JSON::ParserError => e
        Rails.logger.error "[ConsultationAI] JSON parse error: #{e.message}"
        { patient_report: content.to_s, colleague_subject: "", colleague_body: "" }
      end

      def colleague_label(kind)
        {
          "prosthetist" => "prothésiste dentaire",
          "referring_dentist" => "chirurgien-dentiste référent",
          "radiologist" => "radiologue",
          "periodontist" => "parodontologue",
          "orthodontist" => "orthodontiste",
          "other" => "confrère spécialiste"
        }[kind.to_s] || "confrère"
      end

      def fallback_report(transcript_lines, patient_name, colleague_kind)
        date_str = Time.zone.today.strftime("%d/%m/%Y")
        report = <<~MD
          ## Compte rendu de consultation

          **Patient** : #{patient_name}
          **Date** : #{date_str}

          ### Transcription brute
          #{transcript_lines.map { |l| "- #{l}" }.join("\n")}

          ---
          _Compte rendu généré automatiquement — à valider par le praticien._
        MD

        letter = fallback_colleague_letter(colleague_kind)

        {
          patient_report: report.strip,
          colleague_subject: letter["subject"],
          colleague_body: letter["body"]
        }
      end

      def fallback_colleague_letter(kind)
        label = colleague_label(kind)
        {
          "subject" => "Compte rendu de consultation — coordination #{label}",
          "body" => "Bonjour,\n\nVeuillez trouver les éléments cliniques issus de la consultation du jour.\n\nCordialement,"
        }
      end
    end
  end
end
