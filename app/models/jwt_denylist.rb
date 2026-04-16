# frozen_string_literal: true

class JwtDenylist < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  scope :expired, -> { where("exp < ?", Time.current) }

  def self.revoke!(jti:, exp:)
    create!(jti: jti, exp: Time.at(exp))
  end

  def self.revoked?(jti)
    where(jti: jti).exists?
  end

  def self.purge_expired!
    expired.delete_all
  end
end
