module AuthHelpers
  def auth_headers_for(account)
    token_data = ::Auth::TokenIssuer.issue_access_token(account)
    { "Authorization" => "Bearer #{token_data[:access_token]}" }
  end

  def org_header_for(organization)
    { "X-Organization-Id" => organization.id.to_s }
  end

  def api_headers(account, organization)
    auth_headers_for(account)
      .merge(org_header_for(organization))
      .merge("Content-Type" => "application/json", "Accept" => "application/json")
  end

  def json_body
    JSON.parse(response.body)
  end
end
