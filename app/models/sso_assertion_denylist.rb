# frozen_string_literal: true

# Anti-replay store for SSO assertions received from turboapp.
# Same pattern as JwtDenylist but for cross-app assertions.
class SsoAssertionDenylist < ApplicationRecord
  self.table_name = "sso_assertion_denylist"

  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  scope :expired, -> { where("exp < ?", Time.current) }

  def self.consume!(jti:, exp:)
    exp_time = Time.zone.at(exp.to_i)
    # Course ou double appel : la contrainte unique sur jti (ou la validation) peut
    # faire echouer le second INSERT — on recharge la ligne existante.
    create!(jti: jti, exp: exp_time)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    find_by!(jti: jti)
  end

  def self.consumed?(jti)
    where(jti: jti).exists?
  end

  def self.purge_expired!
    expired.delete_all
  end
end
