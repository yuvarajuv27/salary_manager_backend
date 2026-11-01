# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayCalculator do
  def rule(name:, position:, side:, kind:, percent: nil, amount_minor: nil, ceiling_minor: nil)
    OpenStruct.new(name:, position:, side:, kind:, percent:, amount_minor:, ceiling_minor:)
  end

  it "calculates the FR-19 worked example in USD minor units" do
    rules = [
      rule(name: "Tax", position: 0, side: "employee_deduction", kind: "percent", percent: BigDecimal("10")),
      rule(name: "Employer PF", position: 1, side: "employer_contribution", kind: "percent",
           percent: BigDecimal("12"), ceiling_minor: 800_000),
      rule(name: "Insurance", position: 2, side: "employee_deduction", kind: "fixed", amount_minor: 50_000)
    ]

    result = described_class.call(rules:, gross_minor: 1_000_000, currency: "USD")

    expect(result.deductions.map(&:computed_minor)).to eq([100_000, 50_000])
    expect(result.employer_contributions.map(&:computed_minor)).to eq([96_000])
    expect(result.net_minor).to eq(850_000)
    expect(result.employer_cost_minor).to eq(1_096_000)
  end

  it "puts earning rounding remainder on the last earning in list order" do
    rules = [
      rule(name: "Base", position: 0, side: "earning", kind: "percent", percent: BigDecimal("33.3333")),
      rule(name: "Allowance", position: 1, side: "earning", kind: "percent", percent: BigDecimal("66.6667"))
    ]

    result = described_class.call(rules:, gross_minor: 1_000_000, currency: "USD")

    expect(result.earnings.map(&:computed_minor)).to eq([333_333, 666_667])
    expect(result.earnings.sum(&:computed_minor)).to eq(1_000_000)
  end

  it "floors net at zero when deductions exceed gross" do
    rules = [
      rule(name: "Insurance", position: 0, side: "employee_deduction", kind: "fixed", amount_minor: 1_200_000)
    ]

    result = described_class.call(rules:, gross_minor: 1_000_000, currency: "USD")

    expect(result.net_minor).to eq(0)
    expect(result.employer_cost_minor).to eq(1_000_000)
  end

  it "uses JPY whole-yen rounding for percent lines" do
    rules = [
      rule(name: "Tax", position: 0, side: "employee_deduction", kind: "percent", percent: BigDecimal("10"))
    ]

    result = described_class.call(rules:, gross_minor: 1_005, currency: "JPY")

    expect(result.deductions.first.computed_minor).to eq(101)
    expect(result.net_minor).to eq(904)
  end

  it "returns no lines and gross totals when rules are empty" do
    result = described_class.call(rules: [], gross_minor: 1_000_000, currency: "USD")

    expect(result.earnings).to eq([])
    expect(result.deductions).to eq([])
    expect(result.employer_contributions).to eq([])
    expect(result.net_minor).to eq(1_000_000)
    expect(result.employer_cost_minor).to eq(1_000_000)
  end

  it "raises in preview mode when earning percents do not sum to 100" do
    rules = [
      rule(name: "Base", position: 0, side: "earning", kind: "percent", percent: BigDecimal("50"))
    ]

    expect do
      described_class.call(rules:, gross_minor: 1_000_000, currency: "USD")
    end.to raise_error(described_class::InvalidEarnings)
  end

  it "omits invalid earnings in run mode while still calculating deductions and employer contributions" do
    rules = [
      rule(name: "Base", position: 0, side: "earning", kind: "percent", percent: BigDecimal("50")),
      rule(name: "Tax", position: 1, side: "employee_deduction", kind: "percent", percent: BigDecimal("10")),
      rule(name: "Employer PF", position: 2, side: "employer_contribution", kind: "percent", percent: BigDecimal("12"))
    ]

    result = described_class.call(rules:, gross_minor: 1_000_000, currency: "USD", mode: :run)

    expect(result.earnings).to eq([])
    expect(result.deductions.map(&:computed_minor)).to eq([100_000])
    expect(result.employer_contributions.map(&:computed_minor)).to eq([120_000])
    expect(result.net_minor).to eq(900_000)
    expect(result.employer_cost_minor).to eq(1_120_000)
  end
end
