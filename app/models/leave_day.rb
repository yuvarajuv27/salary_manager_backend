# frozen_string_literal: true

class LeaveDay < ApplicationRecord
  belongs_to :company
  belongs_to :employee

  validates :leave_on, presence: true
  validates :leave_on, uniqueness: { scope: :employee_id }
  validate :employee_belongs_to_company
  validate :leave_on_inside_employment
  validate :leave_on_not_in_credited_month

  before_validation :sync_company_from_employee
  before_destroy :ensure_not_credited_month

  private

  def ensure_not_credited_month
    return if leave_on.blank? || employee.blank?
    return unless Workforce::CreditedMonth.credited?(employee, leave_on.beginning_of_month)

    errors.add(:base, "cannot be changed in a credited month")
    throw :abort
  end

  def sync_company_from_employee
    return unless employee

    self.company_id = employee.company_id
  end

  def employee_belongs_to_company
    return if employee.blank? || company_id.blank?
    return if employee.company_id == company_id

    errors.add(:employee_id, "must belong to the same company")
  end

  def leave_on_inside_employment
    return if leave_on.blank? || employee.blank?
    return if leave_on >= employee.start_on && (employee.end_on.blank? || leave_on <= employee.end_on)

    errors.add(:leave_on, "must fall inside employment dates")
  end

  def leave_on_not_in_credited_month
    return if leave_on.blank? || employee.blank?
    return unless Workforce::CreditedMonth.credited?(employee, leave_on.beginning_of_month)

    errors.add(:leave_on, "cannot be changed in a credited month")
  end
end
