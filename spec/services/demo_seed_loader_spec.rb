# frozen_string_literal: true

require "rails_helper"

RSpec.describe DemoSeedLoader do
  it "loads a multi-entity company with salaries, rules, and open-month payslips" do
    result = described_class.call(entity_count: 2, employees_per_entity: 3)

    company = result.fetch(:company)
    expect(company.legal_name).to eq("Seed Demo Co")
    expect(company.primary_currency).to eq("USD")
    expect(company.entities.count).to eq(2)

    admin = User.find_by!(email: "admin@seed.example")
    expect(admin.access_role).to eq("admin")
    expect(admin.authenticate("Password1!")).to eq(admin)

    expect(PayRule.where(company:).count).to eq(6)
    expect(Employee.where(company:).count).to eq(6)
    expect(SalaryAssignment.where(company:).count).to eq(6)

    run = company.payroll_runs.sole
    expect(run.status).to eq("credited")
    expect(Payslip.where(payroll_run: run).count).to eq(6)
    expect(EntityCredit.where(payroll_run: run).pluck(:status).uniq).to eq(["credited"])
  end

  it "aborts when the seed admin already exists" do
    company = Company.create!(
      legal_name: "Existing",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 12, 31)
    )
    User.create!(
      company:,
      name: "Existing Admin",
      email: "admin@seed.example",
      password: "Password1!",
      access_role: "admin"
    )

    expect { described_class.call(entity_count: 1, employees_per_entity: 1) }
      .to raise_error(DemoSeedLoader::AlreadySeeded, /admin@seed\.example/)
  end
end
