class Account < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :trackable,
         :validatable,
         :lockable

  enum :account_type, { practitioner: 0, patient: 1 }, validate: true

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :refresh_tokens, dependent: :destroy
  has_many :audit_logs

  validates :account_type, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  before_create :set_jti_secret

  scope :active, -> { where(active: true) }

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  def membership_in(organization)
    memberships.active.find_by(organization: organization)
  end

  def rotate_jti_secret!
    update!(jti_secret: SecureRandom.uuid)
  end

  private

  def set_jti_secret
    self.jti_secret ||= SecureRandom.uuid
  end
end
