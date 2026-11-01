# frozen_string_literal: true

require "rails_helper"

RSpec.describe SalaryWriter do
  def create_company(next_payroll_on: Date.new(2026, 4, 30))
    Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on:
    )
  end

  def create_employee(company, entity, **attrs)
    defaults = {
      name: "Pat Lee",
      job_role: "Engineer",
      department: "Product",
      start_on: Date.new(2026, 1, 1),
      bank_details: {
        "account_holder_name" => "Pat Lee",
        "account_number" => "1234567890",
        "routing_number" => "021000021"
      }
    }
    entity.employees.create!(defaults.merge(attrs).merge(company:))
  end

  it "writes a correction on the first day of the open month" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)

    described_class.correct!(employee, amount_minor: 500_000)

    assignment = employee.salary_assignments.sole
    expect(assignment.effective_on).to eq(Date.new(2026, 4, 1))
    expect(assignment.amount_minor).to eq(500_000)
    expect(employee.salary_on(Date.new(2026, 4, 15))).to eq(500_000)
  end

  it "replaces an existing correction for the open month" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)

    described_class.correct!(employee, amount_minor: 100_000)
    described_class.correct!(employee, amount_minor: 200_000)

    expect(employee.salary_assignments.count).to eq(1)
    expect(employee.salary_on(Date.new(2026, 4, 30))).to eq(200_000)
  end

  it "writes a revision for the first day of the next calendar month" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)

    described_class.revise!(employee, amount_minor: 600_000, saved_on: Date.new(2026, 3, 15))

    assignment = employee.salary_assignments.sole
    expect(assignment.effective_on).to eq(Date.new(2026, 4, 1))
    expect(employee.salary_on(Date.new(2026, 3, 31))).to be_nil
    expect(employee.salary_on(Date.new(2026, 4, 1))).to eq(600_000)
  end

  it "replaces a pending revision saved in the same calendar month" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)

    described_class.revise!(employee, amount_minor: 600_000, saved_on: Date.new(2026, 3, 10))
    described_class.revise!(employee, amount_minor: 700_000, saved_on: Date.new(2026, 3, 20))

    expect(employee.salary_assignments.count).to eq(1)
    expect(employee.salary_on(Date.new(2026, 4, 1))).to eq(700_000)
  end

  it "rejects a correction when the open month is credited" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)
    open_month = company.next_payroll_on.beginning_of_month

    allow(Workforce::CreditedMonth).to receive(:credited?).with(employee, open_month).and_return(true)

    expect do
      described_class.correct!(employee, amount_minor: 100_000)
    end.to raise_error(SalaryWriter::CreditedMonth)
  end

  it "rejects a negative amount" do
    company = create_company
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    employee = create_employee(company, entity)

    expect do
      described_class.correct!(employee, amount_minor: -1)
    end.to raise_error(SalaryWriter::InvalidAmount)
  end
end
