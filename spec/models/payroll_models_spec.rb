# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayrollRun, type: :model do
  describe "uniqueness" do
    it "rejects a second run for the same company and month_on" do
      company = payroll_company
      payroll_run(company, month_on: Date.new(2026, 3, 1))
      duplicate = company.payroll_runs.build(
        month_on: Date.new(2026, 3, 1),
        payroll_on: Date.new(2026, 3, 31),
        primary_currency: "USD",
        status: "processing"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:month_on]).to include("has already been taken")
    end

    it "allows the same month_on for different companies" do
      month = Date.new(2026, 3, 1)
      payroll_run(payroll_company, month_on: month)
      expect(payroll_run(payroll_company, month_on: month)).to be_valid
    end
  end
end

RSpec.describe EntityCredit, type: :model do
  describe "uniqueness" do
    it "rejects a second credit for the same run and entity" do
      company = payroll_company
      entity = payroll_entity(company)
      run = payroll_run(company)
      run.entity_credits.create!(company:, entity:, status: "processing")
      duplicate = run.entity_credits.build(company:, entity:, status: "processing")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:entity_id]).to include("has already been taken")
    end
  end
end

RSpec.describe Payslip, type: :model do
  describe "uniqueness" do
    it "rejects a second payslip for the same run and employee" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      run = payroll_run(company)
      payslip_for(run:, employee:)
      duplicate = run.payslips.build(
        company:,
        entity:,
        employee:,
        currency: entity.currency,
        payable_days: 1,
        leave_days_count: 0,
        outside_days: 30,
        salary_minor: 100,
        gross_minor: 100,
        net_minor: 100,
        employer_cost_minor: 100,
        lines: []
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:employee_id]).to include("has already been taken")
    end
  end
end

RSpec.describe PayrollSkip, type: :model do
  describe "uniqueness" do
    it "rejects a second skip for the same run and employee" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      run = payroll_run(company)
      payroll_skip_for(run:, employee:)
      duplicate = run.payroll_skips.build(company:, entity:, employee:, reason: "monthly_salary_unset")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:employee_id]).to include("has already been taken")
    end
  end
end

RSpec.describe CurrencyConversion, type: :model do
  describe "uniqueness" do
    it "rejects a second conversion for the same run and entity" do
      company = payroll_company
      entity = payroll_entity(company)
      run = payroll_run(company)
      run.currency_conversions.create!(
        company:,
        entity:,
        status: "pending",
        primary_currency: "USD"
      )
      duplicate = run.currency_conversions.build(
        company:,
        entity:,
        status: "pending",
        primary_currency: "USD"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:entity_id]).to include("has already been taken")
    end
  end
end
