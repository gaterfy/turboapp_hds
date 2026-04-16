# frozen_string_literal: true

# admin       – full CRUD
# practitioner – full CRUD
# assistant   – read + create + update of non-sensitive fields only
#               (sensitive field restriction enforced in controller, not here)
class PatientPolicy < ApplicationPolicy
  def index?   = admin? || practitioner? || assistant?
  def show?    = admin? || practitioner? || assistant?
  def create?  = admin? || practitioner? || assistant?
  def update?  = admin? || practitioner? || assistant?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Always scope to the current organization – no global queries allowed
      scope.where(organization: membership.organization)
    end
  end
end
