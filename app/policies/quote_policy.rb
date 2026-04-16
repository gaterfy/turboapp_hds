# frozen_string_literal: true

# admin       – read; validate/sign on behalf of admin policy
# practitioner – full lifecycle: create, edit draft, send, sign, expire
# assistant   – read + create draft + edit draft (no send, no sign)
class QuotePolicy < ApplicationPolicy
  def index?   = admin? || practitioner? || assistant?
  def show?    = admin? || practitioner? || assistant?
  def create?  = practitioner? || assistant?
  def update?  = (practitioner? || assistant?) && record.mutable?
  def destroy? = false

  def send_to_patient? = practitioner? && record.may_send_to_patient?
  def sign?            = practitioner? && record.may_sign?
  def reject?          = practitioner? && record.may_reject?
  def expire?          = (admin? || practitioner?) && record.may_expire?

  def manage_line_items? = (practitioner? || assistant?) && record.mutable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
