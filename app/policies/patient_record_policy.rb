# frozen_string_literal: true

# admin       – read, exceptional modification (no create via API)
# practitioner – full access: read, create, update clinical content
# assistant   – no access by default (clinical data sensitivity)
class PatientRecordPolicy < ApplicationPolicy
  def index?  = admin? || practitioner?
  def show?   = admin? || practitioner?
  def create? = practitioner?
  def update? = practitioner?
  def destroy? = false  # Records are never hard-deleted; use archive!

  def archive? = admin? || practitioner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
