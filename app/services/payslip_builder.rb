# frozen_string_literal: true

class PayslipBuilder
  def self.call(run:, entity:)
    new(run:, entity:).call
  end

  def initialize(run:, entity:)
    @run = run
    @entity = entity
  end

  def call
    entity.employees.find_each do |employee|
      build_employee(employee)
    end
  end

  private

  attr_reader :run, :entity

  def build_employee(employee)
    counts = day_counts(employee)
    return if counts.fetch(:employed_days).zero?

    salary_minor = employee.salary_on(run.payroll_on)
    if salary_minor.nil?
      insert_skip(employee)
    else
      insert_payslip(employee, salary_minor, counts)
    end
  end

  def day_counts(employee)
    leave_dates = employee.leave_days.where(leave_on: month_range).pluck(:leave_on).to_set
    employed_days = 0
    leave_days = 0
    payable_days = 0

    month_range.each do |day|
      unless employed_on?(employee, day)
        next
      end

      employed_days += 1
      if leave_dates.include?(day)
        leave_days += 1
      else
        payable_days += 1
      end
    end

    {
      employed_days:,
      payable_days:,
      leave_days:,
      outside_days: days_in_month - employed_days
    }
  end

  def employed_on?(employee, day)
    day >= employee.start_on && (employee.end_on.nil? || day <= employee.end_on)
  end

  def insert_skip(employee)
    PayrollSkip.insert_all(
      [{
        company_id: run.company_id,
        payroll_run_id: run.id,
        entity_id: entity.id,
        employee_id: employee.id,
        reason: "monthly_salary_unset",
        created_at: Time.current,
        updated_at: Time.current
      }],
      unique_by: :index_payroll_skips_on_payroll_run_id_and_employee_id
    )
  end

  def insert_payslip(employee, salary_minor, counts)
    gross_minor = gross_for(salary_minor, counts.fetch(:payable_days))
    calculated = PayCalculator.call(rules: entity.pay_rules.to_a, gross_minor:, currency: entity.currency, mode: :run)

    Payslip.insert_all(
      [{
        company_id: run.company_id,
        payroll_run_id: run.id,
        entity_id: entity.id,
        employee_id: employee.id,
        currency: entity.currency,
        payable_days: counts.fetch(:payable_days),
        leave_days_count: counts.fetch(:leave_days),
        outside_days: counts.fetch(:outside_days),
        salary_minor:,
        gross_minor:,
        net_minor: calculated.net_minor,
        employer_cost_minor: calculated.employer_cost_minor,
        lines: lines_json(calculated),
        created_at: Time.current,
        updated_at: Time.current
      }],
      unique_by: :index_payslips_on_payroll_run_id_and_employee_id
    )
  end

  def gross_for(salary_minor, payable_days)
    major_amount = Rational(salary_minor) * payable_days / days_in_month / minor_unit_factor
    MoneyRounding.round_half_away_from_zero(major_amount, entity.currency)
  end

  def lines_json(calculated)
    (calculated.earnings + calculated.deductions + calculated.employer_contributions).map do |line|
      {
        position: line.position,
        name: line.name,
        side: line.side,
        kind: line.kind,
        percent: line.percent,
        amount_minor: line.amount_minor,
        ceiling_minor: line.ceiling_minor,
        computed_minor: line.computed_minor
      }
    end
  end

  def month_range
    period_start_on..period_end_on
  end

  def days_in_month
    @days_in_month ||= (period_end_on - period_start_on).to_i + 1
  end

  def period_start_on
    run.try(:period_start_on) || run.month_on
  end

  def period_end_on
    run.try(:period_end_on) || run.month_on.end_of_month
  end

  def minor_unit_factor
    10**MoneyRounding::EXPONENTS.fetch(entity.currency)
  end
end
