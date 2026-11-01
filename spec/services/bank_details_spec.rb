# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankDetails do
  def us_set(overrides = {})
    {
      "account_holder_name" => "Jane Doe",
      "account_number" => "1234567890",
      "routing_number" => "021000021"
    }.merge(overrides.stringify_keys)
  end

  describe ".validate!" do
    it "accepts a complete United States set" do
      expect { described_class.validate!("United States", us_set) }.not_to raise_error
    end

    it "raises when a required field is missing" do
      expect do
        described_class.validate!("United States", us_set.except("routing_number"))
      end.to raise_error(BankDetails::InvalidSet)
    end

    it "raises when an extra field is present" do
      expect do
        described_class.validate!("United States", us_set.merge("ifsc" => "HDFC0001"))
      end.to raise_error(BankDetails::InvalidSet)
    end

    it "raises when a value is blank" do
      expect do
        described_class.validate!("United States", us_set.merge("account_number" => "  "))
      end.to raise_error(BankDetails::InvalidSet)
    end
  end

  describe ".encryptable_json" do
    it "returns only the country keys with stripped string values" do
      expect(described_class.encryptable_json("India", {
        account_holder_name: " Raj ",
        account_number: "1234567890",
        ifsc: "HDFC0001234"
      })).to eq(
        "account_holder_name" => "Raj",
        "account_number" => "1234567890",
        "ifsc" => "HDFC0001234"
      )
    end
  end

  describe ".mask" do
    it "shows the account holder name in full" do
      masked = described_class.mask(us_set)
      expect(masked["account_holder_name"]).to eq("Jane Doe")
    end

    it "shows the last four characters of longer secret fields" do
      masked = described_class.mask(us_set)
      expect(masked["account_number"]).to eq("7890")
      expect(masked["routing_number"]).to eq("0021")
    end

    it "fully masks values shorter than four characters" do
      masked = described_class.mask(us_set.merge("routing_number" => "123"))
      expect(masked["routing_number"]).to eq("****")
    end
  end
end
