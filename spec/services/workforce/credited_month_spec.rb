# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workforce::CreditedMonth, type: :service do
  describe ".credited?" do
    it "is false when the employee has no payslip or skip for the month" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      month = Date.new(2026, 3, 1)

      expect(described_class.credited?(employee, month)).to be(false)
    end

    it "is true when a payslip exists for that month" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      month = Date.new(2026, 3, 1)
      run = payroll_run(company, month_on: month)
      payslip_for(run:, employee:)

      expect(described_class.credited?(employee, month)).to be(true)
    end

    it "is true when a skip exists for that month" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      month = Date.new(2026, 3, 1)
      run = payroll_run(company, month_on: month)
      payroll_skip_for(run:, employee:)

      expect(described_class.credited?(employee, month)).to be(true)
    end

    it "is false for a different month" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      run = payroll_run(company, month_on: Date.new(2026, 3, 1))
      payslip_for(run:, employee:)

      expect(described_class.credited?(employee, Date.new(2026, 4, 1))).to be(false)
    end
  end
end

RSpec.describe Workforce::PayslipGuard, type: :service do
  describe ".employee_has_payslip?" do
    it "is false without any payslip" do
      entity = payroll_entity(payroll_company)
      employee = payroll_employee(entity)

      expect(described_class.employee_has_payslip?(employee)).to be(false)
    end

    it "is true after a payslip is stored" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      payslip_for(run: payroll_run(company), employee:)

      expect(described_class.employee_has_payslip?(employee)).to be(true)
    end
  end

  describe ".entity_has_payslip?" do
    it "is false without any payslip on the entity" do
      entity = payroll_entity(payroll_company)

      expect(described_class.entity_has_payslip?(entity)).to be(false)
    end

    it "is true when any employee on the entity has a payslip" do
      company = payroll_company
      entity = payroll_entity(company)
      employee = payroll_employee(entity)
      payslip_for(run: payroll_run(company), employee:)

      expect(described_class.entity_has_payslip?(entity)).to be(true)
    end
  end
end
