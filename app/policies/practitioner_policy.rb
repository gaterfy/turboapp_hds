# frozen_string_literal: true

# admin       – full management (create, update, activate, deactivate)
# practitioner – read own profile; read others only for scheduling context
# assistant   – read (partial, for scheduling); no structural modification
class PractitionerPolicy < ApplicationPolicy
  def index?   = admin? || practitioner? || assistant?
  def show?    = admin? || practitioner? || assistant?
  def create?  = admin?
  def update?  = admin? || own_practitioner_record?
  def destroy? = false  # Use deactivation, never hard delete

  def deactivate? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
