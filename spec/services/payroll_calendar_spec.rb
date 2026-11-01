# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayrollCalendar do
  include ActiveSupport::Testing::TimeHelpers

  describe ".payroll_on" do
    it "uses the last day when the day is missing in a short month" do
      expect(described_class.payroll_on(Date.new(2026, 2, 1), 31)).to eq(Date.new(2026, 2, 28))
    end
  end

  describe ".next_future_payroll_on" do
    it "skips a payroll instant that has already passed today UTC" do
      travel_to Time.utc(2026, 3, 31, 12, 0, 0) do
        expect(described_class.next_future_payroll_on(31)).to eq(Date.new(2026, 4, 30))
      end
    end
  end

  describe ".next_future_payroll_on_for" do
    it "returns the next weekday for weekly companies" do
      company = Company.new(pay_frequency: "weekly", pay_weekday: 5)
      travel_to Time.utc(2026, 3, 31, 12, 0, 0) do
        # 2026-03-31 is Tuesday; next Friday is 2026-04-03
        expect(described_class.next_future_payroll_on_for(company)).to eq(Date.new(2026, 4, 3))
      end
    end

    it "returns the next biweekly payday from the anchor" do
      company = Company.new(
        pay_frequency: "biweekly",
        pay_weekday: 5,
        biweekly_anchor_on: Date.new(2026, 3, 20)
      )
      travel_to Time.utc(2026, 3, 21, 12, 0, 0) do
        expect(described_class.next_future_payroll_on_for(company)).to eq(Date.new(2026, 4, 3))
      end
    end
  end

  describe ".period_bounds_for" do
    it "uses the calendar month for monthly pay" do
      company = Company.new(pay_frequency: "monthly", payroll_day: 31)
      expect(described_class.period_bounds_for(company, Date.new(2026, 3, 31))).to eq(
        [Date.new(2026, 3, 1), Date.new(2026, 3, 31)]
      )
    end

    it "uses seven days ending on payday for weekly" do
      company = Company.new(pay_frequency: "weekly", pay_weekday: 5)
      expect(described_class.period_bounds_for(company, Date.new(2026, 4, 3))).to eq(
        [Date.new(2026, 3, 28), Date.new(2026, 4, 3)]
      )
    end
  end

  describe ".next_payroll_after" do
    it "advances by fourteen days for biweekly" do
      company = Company.new(pay_frequency: "biweekly", pay_weekday: 5)
      expect(described_class.next_payroll_after(company, Date.new(2026, 4, 3))).to eq(
        Date.new(2026, 4, 17)
      )
    end
  end
end
