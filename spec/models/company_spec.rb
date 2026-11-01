# frozen_string_literal: true

require "rails_helper"

RSpec.describe Company, type: :model do
  def build_company(**attrs)
    described_class.new(
      {
        legal_name: "Acme Corp",
        primary_currency: "USD",
        pay_frequency: "monthly",
        payroll_day: 31,
        next_payroll_on: Date.new(2026, 4, 30)
      }.merge(attrs)
    )
  end

  describe "validations" do
    it "is valid with required attributes" do
      expect(build_company).to be_valid
    end

    it "requires primary_currency to be in the allowed set" do
      company = build_company(primary_currency: "XYZ")
      expect(company).not_to be_valid
      expect(company.errors[:primary_currency]).to be_present
    end

    it "requires payroll_day between 1 and 31 for monthly" do
      expect(build_company(payroll_day: 0)).not_to be_valid
      expect(build_company(payroll_day: 32)).not_to be_valid
    end

    it "requires pay_weekday for weekly" do
      company = build_company(pay_frequency: "weekly", pay_weekday: nil)
      expect(company).not_to be_valid
      expect(company.errors[:pay_weekday]).to be_present
    end

    it "requires pay_weekday and biweekly_anchor_on for biweekly" do
      company = build_company(pay_frequency: "biweekly", pay_weekday: 5, biweekly_anchor_on: nil)
      expect(company).not_to be_valid
      expect(company.errors[:biweekly_anchor_on]).to be_present
    end
  end

  describe "defaults" do
    it "defaults payroll_day to 31" do
      company = described_class.create!(
        legal_name: "Default Day Co",
        primary_currency: "EUR",
        next_payroll_on: Date.new(2026, 5, 31)
      )
      expect(company.payroll_day).to eq(31)
    end
  end
end
