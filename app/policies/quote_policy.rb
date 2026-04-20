# frozen_string_literal: true

# admin       – read; validate/sign on behalf of admin policy
# practitioner – full lifecycle: create, edit draft, send, sign, expire
# assistant   – read + create draft + edit draft (no send, no sign)
class QuotePolicy < ApplicationPolicy
  def index?   = admin? || practitioner? || assistant?
  def by_patient_record? = index? # collection `quotes#by_patient_record` / route `devis`
  def pending_signature? = index?
  def show?    = admin? || practitioner? || assistant?
  def create?  = admin? || practitioner? || assistant?
  def update?  = (admin? || practitioner? || assistant?) && record.mutable?

  def send_to_patient? = (admin? || practitioner?) && record.may_send_to_patient?
  def sign?            = (admin? || practitioner?) && record.may_sign?
  def reject?          = (admin? || practitioner?) && record.may_reject?
  def expire?          = (admin? || practitioner?) && record.may_expire?

  def pdf?    = show?
  def destroy? = (admin? || practitioner?) && record.status == "draft"

  def manage_line_items? = (admin? || practitioner? || assistant?) && record.mutable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: membership.organization)
    end
  end
end
