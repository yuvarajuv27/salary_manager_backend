# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayRule, type: :model do
  def create_company
    Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    )
  end

  def create_entity(company = create_company)
    company.entities.create!(name: "India Ops", country: "India")
  end

  def build_rule(entity, **attrs)
    defaults = {
      name: "Base",
      position: 0,
      side: "earning",
      kind: "percent",
      percent: BigDecimal("50")
    }
    entity.pay_rules.build(defaults.merge(attrs))
  end

  describe "valid rules (FR-17)" do
    it "accepts an earning as a percent of gross with no ceiling or fixed amount" do
      expect(build_rule(create_entity)).to be_valid
    end

    it "accepts a deduction as a percent with an optional ceiling greater than zero" do
      entity = create_entity
      expect(
        build_rule(entity, name: "Tax", side: "employee_deduction", kind: "percent", percent: BigDecimal("10"),
                   ceiling_minor: 800_000)
      ).to be_valid
    end

    it "accepts a deduction as a percent with no ceiling" do
      entity = create_entity
      expect(
        build_rule(entity, name: "Tax", side: "employee_deduction", kind: "percent", percent: BigDecimal("10"))
      ).to be_valid
    end

    it "accepts a deduction as a fixed amount greater than zero with no ceiling" do
      entity = create_entity
      expect(
        build_rule(
          entity,
          name: "Insurance",
          side: "employee_deduction",
          kind: "fixed",
          percent: nil,
          amount_minor: 50_000
        )
      ).to be_valid
    end

    it "accepts an employer contribution as percent or fixed under the same bounds" do
      entity = create_entity
      percent_rule = build_rule(
        entity,
        name: "PF",
        side: "employer_contribution",
        kind: "percent",
        percent: BigDecimal("12"),
        ceiling_minor: 800_000
      )
      fixed_rule = build_rule(
        entity,
        name: "Gratuity",
        side: "employer_contribution",
        kind: "fixed",
        percent: nil,
        amount_minor: 1
      )
      expect(percent_rule).to be_valid
      expect(fixed_rule).to be_valid
    end
  end

  describe "refused rules (FR-17)" do
    it "refuses a blank name" do
      rule = build_rule(create_entity, name: "")
      expect(rule).not_to be_valid
      expect(rule.errors[:name]).to be_present
    end

    it "refuses a percent outside (0, 100]" do
      entity = create_entity
      zero = build_rule(entity, percent: BigDecimal("0"))
      over = build_rule(entity, percent: BigDecimal("100.0001"))
      expect(zero).not_to be_valid
      expect(over).not_to be_valid
    end

    it "refuses a fixed amount at or below zero" do
      rule = build_rule(
        create_entity,
        name: "Fee",
        side: "employee_deduction",
        kind: "fixed",
        percent: nil,
        amount_minor: 0
      )
      expect(rule).not_to be_valid
      expect(rule.errors[:amount_minor]).to be_present
    end

    it "refuses a ceiling at or below zero on a percent deduction or employer rule" do
      entity = create_entity
      rule = build_rule(
        entity,
        name: "Tax",
        side: "employee_deduction",
        kind: "percent",
        percent: BigDecimal("10"),
        ceiling_minor: 0
      )
      expect(rule).not_to be_valid
      expect(rule.errors[:ceiling_minor]).to be_present
    end

    it "refuses a ceiling on a fixed rule" do
      rule = build_rule(
        create_entity,
        name: "Fee",
        side: "employee_deduction",
        kind: "fixed",
        percent: nil,
        amount_minor: 50_000,
        ceiling_minor: 1
      )
      expect(rule).not_to be_valid
      expect(rule.errors[:ceiling_minor]).to be_present
    end

    it "refuses an earning with a fixed amount or a ceiling" do
      entity = create_entity
      with_ceiling = build_rule(entity, ceiling_minor: 1)
      fixed_kind = build_rule(
        entity,
        kind: "fixed",
        percent: nil,
        amount_minor: 100
      )
      expect(with_ceiling).not_to be_valid
      expect(fixed_kind).not_to be_valid
    end

    it "refuses a negative position" do
      rule = build_rule(create_entity, position: -1)
      expect(rule).not_to be_valid
      expect(rule.errors[:position]).to be_present
    end
  end

  describe "associations" do
    it "belongs to an entity in the same company" do
      company = create_company
      entity = create_entity(company)
      rule = build_rule(entity)
      rule.save!
      expect(entity.pay_rules).to include(rule)
      expect(rule.company_id).to eq(company.id)
    end
  end
end
