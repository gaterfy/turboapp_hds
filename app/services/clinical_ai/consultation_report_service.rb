# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module ClinicalAi
  # Generates structured consultation reports and colleague letters from
  # a clinical transcript using OpenAI GPT-4o-mini.
  #
  # Usage:
  #   result = ClinicalAi::ConsultationReportService.new.call(
  #     transcript_lines: ["Patient presents with..."],
  #     patient_name: "J. Dupont",
  #     colleague_kind: "prosthetist"
  #   )
  #   # => { patient_report: "...", colleague_subject: "...", colleague_body: "..." }
  class ConsultationReportService
    OPENAI_URL  = "https://api.openai.com/v1/chat/completions"
    MODEL       = "gpt-4o-mini"
    TEMPERATURE = 0.3
    MAX_TOKENS  = 2000

    SYSTEM_PROMPT = <<~PROMPT
      You are a medical AI assistant specialized in dental surgery.
      You help practitioners structure consultation reports and collegial letters.

      STRICT RULES:
      - Use professional and precise medical language.
      - Never diagnose: you only structure the practitioner's observations.
      - Respect FDI notation for teeth (11-48).
      - Always include: chief complaint, clinical exam, hypothesis/diagnosis, treatment plan, advice.
      - The patient report must be understandable by a non-professional.
      - The colleague letter must be formal and use specialized vocabulary.
      - Reply ONLY in valid JSON, no markdown blocks.
    PROMPT

    COLLEAGUE_LABELS = {
      "prosthetist"       => "dental prosthetist",
      "referring_dentist" => "referring dentist",
      "radiologist"       => "radiologist",
      "periodontist"      => "periodontist",
      "orthodontist"      => "orthodontist",
      "other"             => "specialist colleague"
    }.freeze

    def initialize
      @api_key = ENV.fetch("OPENAI_API_KEY", nil)
      raise ArgumentError, "OPENAI_API_KEY is not configured" if @api_key.blank?
    end

    # Generate full consultation report + colleague letter draft.
    #
    # @param transcript_lines [Array<String>]
    # @param patient_name [String]
    # @param colleague_kind [String] one of COLLEAGUE_LABELS keys
    # @return [Hash] with :patient_report, :colleague_subject, :colleague_body, :model_used
    def call(transcript_lines:, patient_name:, colleague_kind: "referring_dentist")
      raise ArgumentError, "Transcript is empty" if transcript_lines.blank?

      transcript = transcript_lines.join("\n")
      prompt = build_full_prompt(transcript, patient_name, colleague_kind)

      Rails.logger.info "[ClinicalAI] OpenAI call — #{transcript_lines.size} lines, patient=#{patient_name}"

      body = {
        model: MODEL,
        temperature: TEMPERATURE,
        max_tokens: MAX_TOKENS,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user",   content: prompt }
        ]
      }

      data    = openai_request(body)
      content = data.dig("choices", 0, "message", "content")

      Rails.logger.info "[ClinicalAI] Response: #{content&.truncate(200)}"
      parse_report(content, colleague_kind)
    rescue StandardError => e
      Rails.logger.error "[ClinicalAI] #{e.class}: #{e.message}"
      fallback_report(transcript_lines, patient_name, colleague_kind)
    end

    # Generate a standalone colleague letter (lighter call).
    def generate_colleague_letter(transcript_lines:, patient_name:, colleague_kind:)
      raise ArgumentError, "Transcript is empty" if transcript_lines.blank?

      label  = COLLEAGUE_LABELS.fetch(colleague_kind.to_s, "specialist colleague")
      prompt = <<~PROMPT
        Based on this dental consultation transcript, generate a collegial letter
        addressed to a #{label}.

        Patient: #{patient_name}
        Transcript:
        #{transcript_lines.join("\n")}

        Reply in JSON: {"subject": "...", "body": "..."}
        Body must start with "Dear colleague," and end with "Kind regards,"
      PROMPT

      body = {
        model: MODEL,
        temperature: TEMPERATURE,
        max_tokens: 1000,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user",   content: prompt }
        ]
      }

      data    = openai_request(body)
      content = data.dig("choices", 0, "message", "content")
      JSON.parse(content).slice("subject", "body")
    rescue StandardError => e
      Rails.logger.error "[ClinicalAI] Colleague letter error: #{e.class}: #{e.message}"
      fallback_colleague_letter(colleague_kind)
    end

    private

    def build_full_prompt(transcript, patient_name, colleague_kind)
      label = COLLEAGUE_LABELS.fetch(colleague_kind.to_s, "specialist colleague")
      <<~PROMPT
        Here is the transcript of a dental consultation.
        Patient: #{patient_name}

        TRANSCRIPT:
        #{transcript}

        Generate JSON with exactly these keys:
        {
          "patient_report": "structured report in Markdown for the patient",
          "colleague_subject": "subject of the colleague letter (#{label})",
          "colleague_body": "body of the collegial letter"
        }

        patient_report must contain: ## Consultation Report, ### Chief Complaint, ### Clinical Examination, ### Diagnosis & Approach, ### Follow-up Plan, ### Advice.
        Add today's date and a note "validated by your practitioner before sending" at the bottom.
      PROMPT
    end

    def parse_report(content, colleague_kind)
      data = JSON.parse(content)
      {
        patient_report:     data["patient_report"].to_s,
        colleague_subject:  data["colleague_subject"].to_s,
        colleague_body:     data["colleague_body"].to_s,
        model_used:         MODEL
      }
    rescue JSON::ParserError => e
      Rails.logger.error "[ClinicalAI] JSON parse error: #{e.message}"
      { patient_report: content.to_s, colleague_subject: "", colleague_body: "", model_used: MODEL }
    end

    def fallback_report(transcript_lines, patient_name, _colleague_kind)
      date_str = Time.zone.today.strftime("%d/%m/%Y")
      report = <<~MD
        ## Consultation Report

        **Patient**: #{patient_name}
        **Date**: #{date_str}

        ### Raw Transcript
        #{transcript_lines.map { |l| "- #{l}" }.join("\n")}

        ---
        _Auto-generated report — to be validated by the practitioner._
      MD
      {
        patient_report:    report.strip,
        colleague_subject: "Consultation report",
        colleague_body:    fallback_colleague_letter(_colleague_kind)["body"],
        model_used:        "fallback"
      }
    end

    def fallback_colleague_letter(kind)
      label = COLLEAGUE_LABELS.fetch(kind.to_s, "specialist colleague")
      {
        "subject" => "Consultation report — #{label} coordination",
        "body"    => "Dear colleague,\n\nPlease find the clinical details from today's consultation.\n\nKind regards,"
      }
    end

    # Performs the HTTP request to OpenAI with HDS-safe SSL settings.
    def openai_request(body)
      uri  = URI(OPENAI_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      configure_ssl(http)
      http.open_timeout = 15
      http.read_timeout = 120

      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"]  = "application/json"
      req["Authorization"] = "Bearer #{@api_key}"
      req.body = body.to_json

      response = http.request(req)
      raise "OpenAI HTTP #{response.code}: #{response.body&.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    # Keeps VERIFY_PEER while tolerating missing CRL endpoints (OpenSSL 3 / firewalled envs).
    def configure_ssl(http)
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      store.add_file(ENV["SSL_CERT_FILE"]) if ENV["SSL_CERT_FILE"].present? && File.file?(ENV["SSL_CERT_FILE"])
      http.cert_store = store
      http.verify_callback = lambda do |preverify_ok, ctx|
        preverify_ok || ctx.error == OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
      end
    end
  end
end
