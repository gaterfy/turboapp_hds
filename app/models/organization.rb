# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :audit_logs

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, digits and hyphens" }

  scope :active, -> { where(active: true) }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end
end
