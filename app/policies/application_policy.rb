# frozen_string_literal: true

# Base policy. Subclasses override individual permission methods.
#
# Convention: `user` here is a context object { account:, membership: }
# passed from Api::V1::BaseController#pundit_user.
# This allows policies to reason about both identity and organization role.
class ApplicationPolicy
  attr_reader :account, :membership, :record

  def initialize(user_context, record)
    @account    = user_context[:account]
    @membership = user_context[:membership]
    @record     = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  protected

  def admin?
    membership&.admin?
  end

  def practitioner?
    membership&.practitioner?
  end

  def assistant?
    membership&.assistant?
  end

  # True if the account is the practitioner referenced by this record
  def own_practitioner_record?
    record.respond_to?(:account_id) && record.account_id == account.id
  end

  class Scope
    def initialize(user_context, scope)
      @account    = user_context[:account]
      @membership = user_context[:membership]
      @scope      = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class}#resolve is not implemented"
    end

    private

    attr_reader :account, :membership, :scope

    def admin?      = membership&.admin?
    def practitioner? = membership&.practitioner?
    def assistant?  = membership&.assistant?
  end
end
