# frozen_string_literal: true

class User < ApplicationRecord
  ACCESS_ROLES = %w[admin hr].freeze

  belongs_to :company

  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :access_role, presence: true, inclusion: { in: ACCESS_ROLES }
  validate :entity_id_matches_access_role

  private

  def entity_id_matches_access_role
    return if access_role.blank?

    if access_role == "admin" && entity_id.present?
      errors.add(:entity_id, "must be blank for admin")
    elsif access_role == "hr" && entity_id.blank?
      errors.add(:entity_id, "must be present for hr")
    end
  end
end
