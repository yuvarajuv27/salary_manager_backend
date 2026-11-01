# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entity, type: :model do
  def create_company
    Company.create!(
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      next_payroll_on: Date.new(2026, 4, 30)
    )
  end

  def build_entity(company, **attrs)
    company.entities.build({ name: "India Ops", country: "India" }.merge(attrs))
  end

  describe "validations" do
    it "is valid with name and a supported country" do
      expect(build_entity(create_company)).to be_valid
    end

    it "requires a name" do
      entity = build_entity(create_company, name: "")
      expect(entity).not_to be_valid
      expect(entity.errors[:name]).to be_present
    end

    it "requires country to be one of the nine FR-5 countries" do
      entity = build_entity(create_company, country: "Narnia")
      expect(entity).not_to be_valid
      expect(entity.errors[:country]).to be_present
    end
  end

  describe "currency from country" do
    it "sets payout currency from country on create" do
      entity = build_entity(create_company, country: "Japan")
      entity.save!
      expect(entity.currency).to eq("JPY")
    end

    it "does not overwrite currency when country is unchanged on update" do
      entity = build_entity(create_company, country: "Canada")
      entity.save!
      entity.update!(name: "Canada Ops Renamed")
      expect(entity.currency).to eq("CAD")
    end
  end

  describe "associations" do
    it "belongs to a company" do
      company = create_company
      entity = build_entity(company)
      entity.save!
      expect(company.entities).to include(entity)
    end
  end
end
