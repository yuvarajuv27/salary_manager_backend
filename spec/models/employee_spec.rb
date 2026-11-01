# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employee, type: :model do
  def create_company
    Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    )
  end

  def create_entity(company, country: "United States")
    company.entities.create!(name: "Entity", country:, currency: Countries.currency_for(country))
  end

  def valid_bank(country: "United States")
    case country
    when "India"
      {
        "account_holder_name" => "Raj Kumar",
        "account_number" => "1234567890",
        "ifsc" => "HDFC0001234"
      }
    else
      {
        "account_holder_name" => "Jane Doe",
        "account_number" => "1234567890",
        "routing_number" => "021000021"
      }
    end
  end

  def build_employee(company, entity, **attrs)
    entity.employees.build({
      company:,
      name: "Alex",
      job_role: "Analyst",
      department: "Finance",
      start_on: Date.new(2026, 1, 1),
      bank_details: valid_bank(country: entity.country)
    }.merge(attrs))
  end

  describe "validations" do
    it "is valid with required fields and a complete bank set" do
      company = create_company
      entity = create_entity(company)
      expect(build_employee(company, entity)).to be_valid
    end

    it "requires job role and department" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity, job_role: "", department: "")
      expect(employee).not_to be_valid
    end

    it "rejects end_on before start_on" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity, start_on: Date.new(2026, 5, 1), end_on: Date.new(2026, 4, 1))
      expect(employee).not_to be_valid
    end

    it "rejects a partial bank set" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity, bank_details: { "account_holder_name" => "Jane" })
      expect(employee).not_to be_valid
    end
  end

  describe "bank_payload encryption" do
    it "stores ciphertext that does not contain the account number" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity)
      employee.save!

      raw = ActiveRecord::Base.connection.select_value(
        "SELECT bank_payload FROM employees WHERE id = #{employee.id}"
      )
      expect(raw).not_to include("1234567890")
      expect(employee.reload.bank_details_hash["account_number"]).to eq("1234567890")
    end
  end

  describe "#salary_on" do
    it "returns nil when no assignment covers the date" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity)
      employee.save!

      expect(employee.salary_on(Date.new(2026, 2, 1))).to be_nil
    end

    it "returns the latest assignment on or before the date" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity)
      employee.save!
      employee.salary_assignments.create!(company:, effective_on: Date.new(2026, 1, 1), amount_minor: 100_000)
      employee.salary_assignments.create!(company:, effective_on: Date.new(2026, 3, 1), amount_minor: 200_000)

      expect(employee.salary_on(Date.new(2026, 2, 15))).to eq(100_000)
      expect(employee.salary_on(Date.new(2026, 3, 31))).to eq(200_000)
    end

    it "treats zero as a real salary" do
      company = create_company
      entity = create_entity(company)
      employee = build_employee(company, entity)
      employee.save!
      employee.salary_assignments.create!(company:, effective_on: Date.new(2026, 1, 1), amount_minor: 0)

      expect(employee.salary_on(Date.new(2026, 1, 15))).to eq(0)
    end
  end
end
