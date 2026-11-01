# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analytics::AccountAnalytics do
  include PayrollHelpers

  def credit_run!(company, month_on: Date.new(2026, 3, 1))
    payroll_run(company, month_on:, status: "credited")
  end

  def credit_entity_on_run!(run, entity)
    run.entity_credits.create!(company: run.company, entity:, status: "credited")
  end

  def stored_conversion!(run:, entity:, **attrs)
    run.currency_conversions.create!({
      company: run.company,
      entity:,
      status: "stored",
      primary_currency: run.primary_currency,
      rate: 1,
      rate_on: run.payroll_on,
      gross_minor: 0,
      net_minor: 0,
      employer_cost_minor: 0
    }.merge(attrs))
  end

  def pending_conversion!(run:, entity:)
    run.currency_conversions.create!(
      company: run.company,
      entity:,
      status: "pending",
      primary_currency: run.primary_currency
    )
  end

  it "returns empty payload before the first credited month" do
    company = payroll_company

    payload = described_class.call(company:)

    expect(payload).to eq(
      currency: company.primary_currency,
      latest: nil,
      series: [],
      rule_totals: [],
      employer_cost_by_entity: [],
      pending_entity_names: [],
      empty: true
    )
  end

  it "sums stored conversions and omits pending entities from latest totals" do
    company = payroll_company
    entity_a = payroll_entity(company, country: "United States")
    entity_b = payroll_entity(company, country: "United Kingdom")
    run = credit_run!(company)
    credit_entity_on_run!(run, entity_a)
    credit_entity_on_run!(run, entity_b)
    employee_a = payroll_employee(entity_a)
    employee_b = payroll_employee(
      entity_b,
      bank_details: {
        account_holder_name: "Jane Doe",
        account_number: "12345678",
        sort_code: "123456"
      }
    )
    payslip_for(run:, employee: employee_a)
    payslip_for(run:, employee: employee_b)
    stored_conversion!(
      run:, entity: entity_a,
      gross_minor: 5_000_00, net_minor: 4_500_00, employer_cost_minor: 5_500_00
    )
    pending_conversion!(run:, entity: entity_b)

    payload = described_class.call(company:)

    expect(payload[:latest]).to include(
      month_on: Date.new(2026, 3, 1),
      headcount: 1,
      gross_minor: 5_000_00,
      net_minor: 4_500_00,
      employer_cost_minor: 5_500_00
    )
    expect(payload[:pending_entity_names]).to eq([entity_b.name])
    expect(payload[:employer_cost_by_entity]).to eq(
      [{ entity_id: entity_a.id, name: entity_a.name, employer_cost_minor: 5_500_00 }]
    )
  end

  it "includes a credited month on the series with zeros when every conversion is pending" do
    company = payroll_company
    entity = payroll_entity(company)
    run = credit_run!(company)
    credit_entity_on_run!(run, entity)
    payslip_for(run:, employee: payroll_employee(entity))
    pending_conversion!(run:, entity:)

    payload = described_class.call(company:)

    expect(payload[:series]).to eq(
      [{
        month_on: Date.new(2026, 3, 1),
        gross_minor: 0,
        net_minor: 0,
        employer_cost_minor: 0
      }]
    )
    expect(payload[:latest][:headcount]).to eq(0)
    expect(payload[:pending_entity_names]).to eq([entity.name])
  end

  it "converts rule totals from source major units and rounds in primary currency minor units" do
    company = payroll_company(primary_currency: "USD")
    entity = payroll_entity(company)
    entity.update_column(:currency, "JPY")
    run = credit_run!(company)
    credit_entity_on_run!(run, entity)
    employee = payroll_employee(entity)
    payslip_for(
      run:,
      employee:,
      currency: "JPY",
      lines: [{
        "position" => 1, "name" => "Tax", "side" => "employee_deduction", "kind" => "fixed",
        "percent" => nil, "amount_minor" => nil, "ceiling_minor" => nil, "computed_minor" => 1
      }]
    )
    stored_conversion!(run:, entity:, rate: BigDecimal("0.015"))

    payload = described_class.call(company:)

    expect(payload[:rule_totals]).to eq([
      { name: "Tax", side: "employee_deduction", amount_minor: 2 }
    ])
  end
end
