# frozen_string_literal: true

# Permissions on the organization aggregate (non-AR resources scoped by org).
class OrganizationPolicy < ApplicationPolicy
  def analytics_dashboard?
    (admin? || practitioner? || assistant?) && record == membership.organization
  end
end
