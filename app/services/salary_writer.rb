# frozen_string_literal: true

class SalaryWriter
  class CreditedMonth < StandardError; end
  class InvalidAmount < StandardError; end

  def self.correct!(employee, amount_minor:)
    validate_amount!(amount_minor)
    open_month = employee.company.next_payroll_on.beginning_of_month
    raise CreditedMonth, "open month is credited" if Workforce::CreditedMonth.credited?(employee, open_month)

    write_assignment!(employee, effective_on: open_month, amount_minor:)
  end

  def self.revise!(employee, amount_minor:, saved_on: Date.current)
    validate_amount!(amount_minor)
    effective_on = saved_on.to_date.beginning_of_month.next_month.beginning_of_month

    write_assignment!(employee, effective_on:, amount_minor:)
  end

  def self.write_assignment!(employee, effective_on:, amount_minor:)
    assignment = employee.salary_assignments.find_or_initialize_by(effective_on:)
    assignment.company = employee.company
    assignment.amount_minor = amount_minor
    assignment.save!
    assignment
  end
  private_class_method :write_assignment!

  def self.validate_amount!(amount_minor)
    raise InvalidAmount, "amount must be zero or greater" if amount_minor.negative?
  end
  private_class_method :validate_amount!
end
