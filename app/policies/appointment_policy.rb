# frozen_string_literal: true

# admin, practitioner, assistant – all can read, create, update, cancel
# Finalized appointments are locked by the model layer, not the policy.
class AppointmentPolicy < ApplicationPolicy
  def index?   = admin? || practitioner? || assistant?
  def show?    = admin? || practitioner? || assistant?
  def create?  = admin? || practitioner? || assistant?
  def update?  = admin? || practitioner? || assistant?
  def cancel?  = admin? || practitioner? || assistant?
  def destroy? = false  # Appointments are cancelled, never deleted

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
