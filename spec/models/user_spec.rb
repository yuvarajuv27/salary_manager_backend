# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  def create_company
    Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    )
  end

  def build_user(company, **attrs)
    company.users.build(
      {
        name: "Jane Admin",
        email: "jane@example.com",
        password: "password123",
        access_role: "admin"
      }.merge(attrs)
    )
  end

  describe "validations" do
    it "requires a unique email" do
      company = create_company
      build_user(company).save!
      duplicate = build_user(company, email: "jane@example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to be_present
    end

    it "requires admin users to have no entity_id" do
      user = build_user(create_company, access_role: "admin", entity_id: 1)
      expect(user).not_to be_valid
      expect(user.errors[:entity_id]).to be_present
    end

    it "requires hr users to have an entity_id" do
      user = build_user(create_company, access_role: "hr", entity_id: nil)
      expect(user).not_to be_valid
      expect(user.errors[:entity_id]).to be_present
    end

    it "allows hr users with an entity in the same company" do
      company = create_company
      entity = company.entities.create!(name: "India Ops", country: "India", currency: "INR")
      user = build_user(company, access_role: "hr", entity_id: entity.id, email: "hr@example.com")
      expect(user).to be_valid
    end
  end

  describe "has_secure_password" do
    it "authenticates with the correct password" do
      user = build_user(create_company)
      user.save!
      expect(user.authenticate("password123")).to eq(user)
      expect(user.authenticate("wrong")).to be_falsey
    end
  end
end
