# frozen_string_literal: true

# admin       – read only (no clinical writes)
# practitioner – full access while in_progress; read after completed/locked
# assistant   – no access to clinical content
class ConsultationPolicy < ApplicationPolicy
  def index?   = admin? || practitioner?
  def show?    = admin? || practitioner?
  def create?  = practitioner?
  def update?  = practitioner? && record.editable?
  def destroy? = false  # Consultations are never hard-deleted

  def complete? = practitioner? && record.may_complete?
  def seal?     = admin? && record.may_seal?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
