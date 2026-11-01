# frozen_string_literal: true

class SalaryAssignment < ApplicationRecord
  belongs_to :company
  belongs_to :employee

  validates :effective_on, presence: true
  validates :amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :effective_on, uniqueness: { scope: :employee_id }
  validate :employee_belongs_to_company
  validate :effective_on_is_first_of_month

  before_validation :sync_company_from_employee

  private

  def sync_company_from_employee
    return unless employee

    self.company_id = employee.company_id
  end

  def employee_belongs_to_company
    return if employee.blank? || company_id.blank?
    return if employee.company_id == company_id

    errors.add(:employee_id, "must belong to the same company")
  end

  def effective_on_is_first_of_month
    return if effective_on.blank?
    return if effective_on == effective_on.beginning_of_month

    errors.add(:effective_on, "must be the first day of a month")
  end
end
