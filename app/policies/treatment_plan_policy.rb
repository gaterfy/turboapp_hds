# frozen_string_literal: true

class TreatmentPlanPolicy < ApplicationPolicy
  def index?   = admin? || practitioner?
  def show?    = admin? || practitioner?
  def create?  = practitioner?
  def update?  = practitioner? && record.mutable?
  def destroy? = false

  def accept?   = (admin? || practitioner?) && record.may_accept?
  def start?    = (admin? || practitioner?) && record.may_start?
  def complete? = practitioner? && record.may_complete?
  def cancel?   = (admin? || practitioner?) && record.may_cancel?

  def manage_items? = practitioner? && record.mutable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
