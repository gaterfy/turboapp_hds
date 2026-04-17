# frozen_string_literal: true

module TurboappSso
  # Apres echange SSO reussi : rattache le compte praticien au cabinet HDS
  # identifie par `merchant_id` turboapp (cle stable). Le nom affiche vient
  # de la claim signee `organization_name` (ex. company_name du merchant).
  class CabinetProvisioner
    DEFAULT_SPECIALIZATION = "Dentisterie générale"

    def self.call(account:, payload:)
      new(account: account, payload: payload).call
    end

    def initialize(account:, payload:)
      @account = account
      @payload = payload
    end

    def call
      merchant_id = @payload["merchant_id"].to_s.strip
      return if merchant_id.blank?
      return unless @account.practitioner?

      Organization.transaction do
        org = provision_organization!(merchant_id)
        ensure_membership!(org)
        ensure_practitioner!(org, merchant_id)
      end
    end

    private

    def provision_organization!(merchant_id)
      Organization.find_by(turboapp_merchant_id: merchant_id) ||
        create_organization!(merchant_id)
    end

    def create_organization!(merchant_id)
      name = organization_display_name
      slug = "merchant-#{merchant_id.delete('-').downcase}"
      Organization.create!(
        name: name,
        slug: slug,
        turboapp_merchant_id: merchant_id,
        active: true
      )
    rescue ActiveRecord::RecordNotUnique
      Organization.find_by!(turboapp_merchant_id: merchant_id)
    end

    def organization_display_name
      @payload["organization_name"].presence ||
        @payload["cabinet_name"].presence ||
        "Cabinet"
    end

    def ensure_membership!(org)
      m = Membership.find_or_initialize_by(account: @account, organization: org)
      m.role = :admin
      m.active = true
      m.save!
    end

    def ensure_practitioner!(org, merchant_id)
      return if Practitioner.exists?(account: @account, organization: org)

      email = @payload["sub"].to_s.downcase.strip
      first_name, last_name = split_display_name(email)

      Practitioner.create!(
        organization: org,
        account: @account,
        first_name: first_name,
        last_name: last_name,
        email: email,
        specialization: DEFAULT_SPECIALIZATION,
        license_number: "SSO-#{merchant_id.delete('-')}-#{@account.id}",
        clinical_role: "owner",
        status: "active"
      )
    end

    def split_display_name(email)
      raw = @payload["name"].to_s.strip
      if raw.present?
        parts = raw.split(/\s+/, 2)
        return [parts[0].presence || "Praticien", parts[1].presence || "-"]
      end

      local = email.split("@", 2).first.to_s
      [local.presence || "Praticien", "-"]
    end
  end
end
