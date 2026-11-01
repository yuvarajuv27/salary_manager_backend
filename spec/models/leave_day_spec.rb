# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeaveDay, type: :model do
  def create_employee
    company = Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    )
    entity = company.entities.create!(name: "US Entity", country: "United States", currency: "USD")
    entity.employees.create!(
      company:,
      name: "Pat Lee",
      job_role: "Engineer",
      department: "Product",
      start_on: Date.new(2026, 1, 1),
      end_on: Date.new(2026, 12, 31),
      bank_details: {
        "account_holder_name" => "Pat Lee",
        "account_number" => "1234567890",
        "routing_number" => "021000021"
      }
    )
  end

  it "requires leave_on to fall inside employment dates" do
    employee = create_employee
    leave_day = employee.leave_days.build(company: employee.company, leave_on: Date.new(2025, 12, 31))

    expect(leave_day).not_to be_valid
    expect(leave_day.errors[:leave_on]).to be_present
  end

  it "rejects leave in a credited month for the employee" do
    employee = create_employee
    leave_on = Date.new(2026, 3, 10)
    allow(Workforce::CreditedMonth).to receive(:credited?).with(employee, leave_on.beginning_of_month).and_return(true)

    leave_day = employee.leave_days.build(company: employee.company, leave_on:)

    expect(leave_day).not_to be_valid
    expect(leave_day.errors[:leave_on]).to be_present
  end
end
