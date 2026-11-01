# frozen_string_literal: true

require "rails_helper"

RSpec.describe Countries do
  describe ".currency_for" do
    it "returns INR for India" do
      expect(described_class.currency_for("India")).to eq("INR")
    end

    it "returns EUR for Portugal and France" do
      expect(described_class.currency_for("Portugal")).to eq("EUR")
      expect(described_class.currency_for("France")).to eq("EUR")
    end

    it "raises for an unknown country" do
      expect { described_class.currency_for("Narnia") }.to raise_error(KeyError)
    end
  end

  describe ".all" do
    it "lists the nine FR-5 countries" do
      expect(described_class.all).to contain_exactly(
        "India",
        "United States",
        "United Kingdom",
        "Canada",
        "Japan",
        "Australia",
        "Singapore",
        "Portugal",
        "France"
      )
    end
  end

  describe ".valid?" do
    it "is true for a known country" do
      expect(described_class.valid?("Canada")).to be(true)
    end

    it "is false for an unknown country" do
      expect(described_class.valid?("Narnia")).to be(false)
    end
  end
end
