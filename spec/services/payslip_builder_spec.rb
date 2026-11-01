# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayslipBuilder, type: :service do
  subject(:build) { described_class.call(run:, entity:) }

  let(:company) { payroll_company }
  let(:entity) { payroll_entity(company) }
  let(:run) { payroll_run(company, month_on: Date.new(2026, 4, 1)) }

  def assign_salary(employee, amount_minor)
    employee.salary_assignments.create!(effective_on: Date.new(2026, 4, 1), amount_minor:)
  end

  it "credits employed salaried employees with prorated run-mode calculator lines" do
    employee = payroll_employee(entity, start_on: Date.new(2026, 4, 11))
    assign_salary(employee, 3_000_00)
    entity.pay_rules.create!(name: "Base", position: 0, side: "earning", kind: "percent", percent: 100)
    entity.pay_rules.create!(name: "Tax", position: 1, side: "employee_deduction", kind: "percent", percent: 10)
    entity.pay_rules.create!(name: "PF", position: 2, side: "employer_contribution", kind: "fixed", amount_minor: 500_00)

    build

    payslip = Payslip.find_by!(employee:)
    expect(payslip).to have_attributes(
      payable_days: 20,
      leave_days_count: 0,
      outside_days: 10,
      salary_minor: 3_000_00,
      gross_minor: 2_000_00,
      net_minor: 1_800_00,
      employer_cost_minor: 2_500_00
    )
    expect(payslip.lines.pluck("name", "computed_minor")).to eq([["Base", 2_000_00], ["Tax", 200_00], ["PF", 500_00]])
  end

  it "stores a zero-gross payslip when all employed days are leave" do
    employee = payroll_employee(entity)
    assign_salary(employee, 3_100_00)
    (Date.new(2026, 4, 1)..Date.new(2026, 4, 30)).each do |day|
      employee.leave_days.create!(leave_on: day)
    end

    build

    expect(Payslip.find_by!(employee:)).to have_attributes(
      payable_days: 0,
      leave_days_count: 30,
      outside_days: 0,
      gross_minor: 0,
      net_minor: 0,
      employer_cost_minor: 0
    )
  end

  it "records a skip when an employed employee has no salary" do
    employee = payroll_employee(entity)

    build

    expect(PayrollSkip.find_by!(employee:)).to have_attributes(reason: "monthly_salary_unset")
    expect(Payslip.exists?(employee:)).to be(false)
  end

  it "writes nothing for an employee with no employment day in the run month" do
    employee = payroll_employee(entity, start_on: Date.new(2026, 5, 1))
    assign_salary(employee, 3_000_00)

    build

    expect(Payslip.exists?(employee:)).to be(false)
    expect(PayrollSkip.exists?(employee:)).to be(false)
  end

  it "finishes without rows for an empty entity" do
    expect { build }.not_to change { Payslip.count + PayrollSkip.count }
  end

  it "is idempotent across repeated builds" do
    salaried = payroll_employee(entity, name: "Salaried")
    skipped = payroll_employee(entity, name: "Skipped")
    assign_salary(salaried, 3_000_00)

    2.times { build }

    expect(Payslip.where(employee: salaried).count).to eq(1)
    expect(PayrollSkip.where(employee: skipped).count).to eq(1)
  end
end
