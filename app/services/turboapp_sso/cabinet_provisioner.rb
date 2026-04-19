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
      name = organization_display_name
      slug = organization_slug(merchant_id)
      org = begin
        Organization.create!(
          name: name,
          slug: slug,
          turboapp_merchant_id: merchant_id,
          active: true
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        Organization.find_by!(turboapp_merchant_id: merchant_id)
      end
      org.update!(name: name, active: true) if org.name != name || org.active != true
      org
    end

    def organization_slug(merchant_id)
      "merchant-#{merchant_id.delete('-').downcase}"
    end

    def organization_display_name
      @payload["organization_name"].presence ||
        @payload["cabinet_name"].presence ||
        "Cabinet"
    end

    def ensure_membership!(org)
      m = begin
        row = Membership.find_or_initialize_by(account: @account, organization: org)
        row.role = :admin
        row.active = true
        row.save!
        row
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        Membership.find_by!(account: @account, organization: org)
      end
      m.update!(role: :admin, active: true) unless m.admin? && m.active == true
    end

    def ensure_practitioner!(org, merchant_id)
      email = @payload["sub"].to_s.downcase.strip
      first_name, last_name = split_display_name(email)
      license_number = "SSO-#{merchant_id.delete('-')}-#{@account.id}"

      p = begin
        Practitioner.create!(
          organization: org,
          account: @account,
          first_name: first_name,
          last_name: last_name,
          email: email,
          specialization: DEFAULT_SPECIALIZATION,
          license_number: license_number,
          clinical_role: "owner",
          status: "active"
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        Practitioner.find_by!(organization: org, license_number: license_number)
      end

      p.update!(
        account: @account,
        first_name: first_name,
        last_name: last_name,
        email: email,
        specialization: DEFAULT_SPECIALIZATION,
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
