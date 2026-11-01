# frozen_string_literal: true

module PayrollHelpers
  def payroll_company(**attrs)
    Company.create!({
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    }.merge(attrs))
  end

  def payroll_entity(company, country: "United States")
    company.entities.create!(name: "Entity", country:, currency: Countries.currency_for(country))
  end

  def payroll_employee(entity, **attrs)
    entity.employees.create!({
      company: entity.company,
      name: "Alex",
      job_role: "Analyst",
      department: "Finance",
      start_on: Date.new(2026, 1, 1),
      bank_details: {
        account_holder_name: "Jane Doe",
        account_number: "1234567890",
        routing_number: "021000021"
      }
    }.merge(attrs))
  end

  def payroll_run(company, month_on: Date.new(2026, 3, 1), **attrs)
    company.payroll_runs.create!({
      month_on:,
      payroll_on: month_on.end_of_month,
      period_start_on: month_on,
      period_end_on: month_on.end_of_month,
      primary_currency: company.primary_currency,
      status: "processing"
    }.merge(attrs))
  end

  def payslip_for(run:, employee:, **attrs)
    run.payslips.create!({
      company: run.company,
      entity: employee.entity,
      employee:,
      currency: employee.entity.currency,
      payable_days: 20,
      leave_days_count: 0,
      outside_days: 11,
      salary_minor: 5_000_00,
      gross_minor: 5_000_00,
      net_minor: 4_500_00,
      employer_cost_minor: 5_500_00,
      lines: []
    }.merge(attrs))
  end

  def payroll_skip_for(run:, employee:, reason: "monthly_salary_unset")
    run.payroll_skips.create!(
      company: run.company,
      entity: employee.entity,
      employee:,
      reason:
    )
  end
end

RSpec.configure do |config|
  config.include PayrollHelpers, type: :model
  config.include PayrollHelpers, type: :service
  config.include PayrollHelpers, type: :request
  config.include PayrollHelpers, type: :job
end
