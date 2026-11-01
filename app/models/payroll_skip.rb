# frozen_string_literal: true

class PayrollSkip < ApplicationRecord
  REASONS = %w[monthly_salary_unset].freeze

  belongs_to :company
  belongs_to :payroll_run
  belongs_to :entity
  belongs_to :employee

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validate :payroll_run_belongs_to_company
  validate :entity_belongs_to_company
  validate :employee_belongs_to_entity

  before_validation :sync_company_from_employee

  private

  def sync_company_from_employee
    return unless employee

    self.company_id = employee.company_id
    self.entity_id = employee.entity_id
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

  def employee_belongs_to_entity
    return if employee.blank? || entity_id.blank?
    return if employee.entity_id == entity_id

    errors.add(:employee_id, "must belong to the skip entity")
  end
end
