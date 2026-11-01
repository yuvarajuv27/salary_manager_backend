# frozen_string_literal: true

class Payslip < ApplicationRecord
  belongs_to :company
  belongs_to :payroll_run
  belongs_to :entity
  belongs_to :employee

  validates :currency, :payable_days, :leave_days_count, :outside_days,
            :salary_minor, :gross_minor, :net_minor, :employer_cost_minor, presence: true
  validates :payable_days, :leave_days_count, :outside_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :salary_minor, :gross_minor, :net_minor, :employer_cost_minor,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validate :payroll_run_belongs_to_company
  validate :entity_belongs_to_company
  validate :employee_belongs_to_entity

  before_validation :sync_company_from_employee
  before_validation :default_lines

  private

  def default_lines
    self.lines = [] if lines.nil?
  end

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

    errors.add(:employee_id, "must belong to the payslip entity")
  end
end
