# frozen_string_literal: true

# admin       – read only
# practitioner – full lifecycle: create, edit draft, sign, deliver, cancel
# assistant   – no access (prescriptions require clinical authority)
class PrescriptionPolicy < ApplicationPolicy
  def index?   = admin? || practitioner?
  def show?    = admin? || practitioner?
  def create?  = practitioner?
  def update?  = practitioner? && record.mutable?
  def destroy? = false

  def sign?    = practitioner? && record.may_sign?
  def deliver? = practitioner? && record.may_deliver?
  def cancel?  = (admin? || practitioner?) && record.may_cancel?

  def manage_line_items? = practitioner? && record.mutable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
