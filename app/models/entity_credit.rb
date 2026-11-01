# frozen_string_literal: true

class EntityCredit < ApplicationRecord
  STATUSES = %w[processing credited].freeze

  belongs_to :company
  belongs_to :payroll_run
  belongs_to :entity

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :entity_id, uniqueness: { scope: :payroll_run_id }
  validate :payroll_run_belongs_to_company
  validate :entity_belongs_to_company

  before_validation :sync_company_from_payroll_run

  private

  def sync_company_from_payroll_run
    return unless payroll_run

    self.company_id = payroll_run.company_id
  end

  def payroll_run_belongs_to_company
    return if payroll_run.blank? || company_id.blank?
    return if payroll_run.company_id == company_id

    errors.add(:payroll_run_id, "must belong to the same company")
  end

  def entity_belongs_to_company
    return if entity.blank? || company_id.blank?
    return if entity.company_id == company_id

    errors.add(:entity_id, "must belong to the same company")
  end
end
