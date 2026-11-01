# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::EntityAnalytics do
  include PayrollHelpers

  def credit_entity!(entity, month_on: Date.new(2026, 3, 1))
    run = payroll_run(entity.company, month_on:, status: "credited")
    run.entity_credits.create!(company: entity.company, entity:, status: "credited")
    run
  end

  it "returns empty payload before the first credited month" do
    entity = payroll_entity(payroll_company)

    payload = described_class.call(entity:)

    expect(payload).to eq(
      currency: entity.currency,
      latest: nil,
      series: [],
      rule_totals: [],
      empty: true
    )
  end

  it "counts payslips for headcount including zero-gross and excludes skips" do
    entity = payroll_entity(payroll_company)
    run = credit_entity!(entity)
    payslip_for(run:, employee: payroll_employee(entity))
    zero_employee = payroll_employee(entity, name: "Zero")
    payslip_for(run:, employee: zero_employee, gross_minor: 0, net_minor: 0, employer_cost_minor: 0)
    skipped = payroll_employee(entity, name: "Skip")
    payroll_skip_for(run:, employee: skipped)

    payload = described_class.call(entity:)

    expect(payload[:empty]).to be(false)
    expect(payload[:latest]).to include(
      month_on: Date.new(2026, 3, 1),
      headcount: 2,
      gross_minor: 5_000_00,
      net_minor: 4_500_00,
      employer_cost_minor: 5_500_00
    )
  end

  it "returns the last twelve credited months in the series" do
    entity = payroll_entity(payroll_company)
    employee = payroll_employee(entity)
    13.times do |index|
      month_on = Date.new(2025, 1, 1) >> index
      run = credit_entity!(entity, month_on:)
      payslip_for(
        run:,
        employee:,
        gross_minor: (index + 1) * 100,
        net_minor: (index + 1) * 90,
        employer_cost_minor: (index + 1) * 110
      )
    end

    payload = described_class.call(entity:)

    expect(payload[:series].size).to eq(12)
    expect(payload[:series].first[:month_on]).to eq(Date.new(2025, 2, 1))
    expect(payload[:series].last[:month_on]).to eq(Date.new(2026, 1, 1))
    expect(payload[:series].first[:gross_minor]).to eq(200)
  end

  it "totals employee deductions and employer contributions by rule name" do
    entity = payroll_entity(payroll_company)
    run = credit_entity!(entity)
    employee = payroll_employee(entity)
    other = payroll_employee(entity, name: "Sam")
    deduction_line = {
      "position" => 1, "name" => "Tax", "side" => "employee_deduction", "kind" => "fixed",
      "percent" => nil, "amount_minor" => nil, "ceiling_minor" => nil, "computed_minor" => 500_00
    }
    employer_line = {
      "position" => 2, "name" => "PF", "side" => "employer_contribution", "kind" => "fixed",
      "percent" => nil, "amount_minor" => nil, "ceiling_minor" => nil, "computed_minor" => 300_00
    }
    earning_line = {
      "position" => 0, "name" => "Base", "side" => "earning", "kind" => "percent",
      "percent" => "100.0000", "amount_minor" => nil, "ceiling_minor" => nil, "computed_minor" => 5_000_00
    }
    payslip_for(run:, employee:, lines: [earning_line, deduction_line, employer_line])
    payslip_for(run:, employee: other, lines: [earning_line, deduction_line])

    payload = described_class.call(entity:)

    expect(payload[:rule_totals]).to contain_exactly(
      { name: "Tax", side: "employee_deduction", amount_minor: 1_000_00 },
      { name: "PF", side: "employer_contribution", amount_minor: 300_00 }
    )
  end
end
