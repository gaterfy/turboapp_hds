module AuthHelpers
  # By default we issue tokens with mfa_verified: true because virtually all
  # clinical specs operate under the "authenticated practitioner" assumption.
  # Specs that exercise the MFA challenge flow explicitly pass mfa_verified: false.
  def auth_headers_for(account, mfa_verified: true)
    token_data = ::Auth::TokenIssuer.issue_access_token(account, mfa_verified: mfa_verified)
    { "Authorization" => "Bearer #{token_data[:access_token]}" }
  end

  def org_header_for(organization)
    { "X-Organization-Id" => organization.id.to_s }
  end

  def api_headers(account, organization, mfa_verified: true)
    auth_headers_for(account, mfa_verified: mfa_verified)
      .merge(org_header_for(organization))
      .merge("Content-Type" => "application/json", "Accept" => "application/json")
  end

  def json_body
    JSON.parse(response.body)
  end
end
