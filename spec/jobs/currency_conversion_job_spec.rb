# frozen_string_literal: true

require "rails_helper"

RSpec.describe CurrencyConversionJob, type: :job do
  include PayrollHelpers

  let(:iban_bank_details) do
    { account_holder_name: "Jane Doe", iban: "FR1420041010050500013M02606" }
  end

  FakeClient = Struct.new(:responses, :calls, keyword_init: true) do
    def rate_on(date:, from:, to:)
      calls << { date:, from:, to: }
      response = responses.fetch([date, from, to])
      raise response if response.is_a?(Exception)

      response
    end
  end

  around do |example|
    previous_client = described_class.client
    example.run
    described_class.client = previous_client
  end

  it "stores rate 1 on the payroll date when currencies match" do
    company = payroll_company(primary_currency: "USD")
    entity = payroll_entity(company, country: "United States")
    run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
    employee = payroll_employee(entity)
    payslip_for(run:, employee:, gross_minor: 1_000_00, net_minor: 900_00, employer_cost_minor: 1_100_00)
    described_class.client = FakeClient.new(responses: {}, calls: [])

    described_class.perform_now(run.id, entity.id)

    conversion = CurrencyConversion.find_by!(payroll_run: run, entity:)
    expect(conversion).to have_attributes(
      status: "stored",
      rate: BigDecimal("1.0"),
      rate_on: Date.new(2026, 4, 30),
      gross_minor: 1_000_00,
      net_minor: 900_00,
      employer_cost_minor: 1_100_00
    )
    expect(described_class.client.calls).to be_empty
  end

  it "stores the previous business day's published rate when payroll date is missing" do
    company = payroll_company(primary_currency: "USD")
    entity = payroll_entity(company, country: "France")
    run = payroll_run(company, month_on: Date.new(2026, 5, 1), payroll_on: Date.new(2026, 5, 31))
    employee = payroll_employee(entity, bank_details: iban_bank_details)
    payslip_for(run:, employee:, gross_minor: 100_00, net_minor: 80_00, employer_cost_minor: 120_00)
    described_class.client = FakeClient.new(
      responses: {
        [Date.new(2026, 5, 31), "EUR", "USD"] => {
          date: Date.new(2026, 5, 29),
          rate: BigDecimal("1.25")
        }
      },
      calls: []
    )

    described_class.perform_now(run.id, entity.id)

    conversion = CurrencyConversion.find_by!(payroll_run: run, entity:)
    expect(conversion).to have_attributes(
      status: "stored",
      rate_on: Date.new(2026, 5, 29),
      gross_minor: 125_00,
      net_minor: 100_00,
      employer_cost_minor: 150_00
    )
    expect(described_class.client.calls).to contain_exactly(
      { date: Date.new(2026, 5, 31), from: "EUR", to: "USD" }
    )
  end

  it "leaves a pending conversion when the client fails" do
    company = payroll_company(primary_currency: "USD")
    entity = payroll_entity(company, country: "France")
    run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
    employee = payroll_employee(entity, bank_details: iban_bank_details)
    payslip_for(run:, employee:)
    described_class.client = FakeClient.new(
      responses: { [Date.new(2026, 4, 30), "EUR", "USD"] => Timeout::Error.new("timeout") },
      calls: []
    )

    described_class.perform_now(run.id, entity.id)

    conversion = CurrencyConversion.find_by!(payroll_run: run, entity:)
    expect(conversion).to have_attributes(status: "pending", rate: nil, rate_on: nil)
  end

  it "fills a pending row later using the original payroll date" do
    company = payroll_company(primary_currency: "USD")
    entity = payroll_entity(company, country: "France")
    run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
    employee = payroll_employee(entity, bank_details: iban_bank_details)
    payslip_for(run:, employee:, gross_minor: 200_00, net_minor: 150_00, employer_cost_minor: 250_00)
    run.currency_conversions.create!(entity:, status: "pending", primary_currency: "USD")
    described_class.client = FakeClient.new(
      responses: {
        [Date.new(2026, 4, 30), "EUR", "USD"] => {
          date: Date.new(2026, 4, 30),
          rate: BigDecimal("1.5")
        }
      },
      calls: []
    )

    described_class.perform_now(run.id, entity.id)

    conversion = CurrencyConversion.find_by!(payroll_run: run, entity:)
    expect(conversion).to have_attributes(
      status: "stored",
      rate_on: Date.new(2026, 4, 30),
      gross_minor: 300_00,
      net_minor: 225_00,
      employer_cost_minor: 375_00
    )
    expect(described_class.client.calls.first.fetch(:date)).to eq(Date.new(2026, 4, 30))
  end
end
