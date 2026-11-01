# frozen_string_literal: true

class Countries
  COUNTRY_BANK_FIELDS = {
    "India" => %w[account_holder_name account_number ifsc],
    "United States" => %w[account_holder_name account_number routing_number],
    "United Kingdom" => %w[account_holder_name account_number sort_code],
    "Canada" => %w[account_holder_name account_number institution_number transit_number],
    "Japan" => %w[account_holder_name account_number bank_code branch_code],
    "Australia" => %w[account_holder_name account_number bsb],
    "Singapore" => %w[account_holder_name account_number bank_code],
    "Portugal" => %w[account_holder_name iban],
    "France" => %w[account_holder_name iban]
  }.freeze

  COUNTRY_TO_CURRENCY = {
    "India" => "INR",
    "United States" => "USD",
    "United Kingdom" => "GBP",
    "Canada" => "CAD",
    "Japan" => "JPY",
    "Australia" => "AUD",
    "Singapore" => "SGD",
    "Portugal" => "EUR",
    "France" => "EUR"
  }.freeze

  def self.all
    COUNTRY_TO_CURRENCY.keys
  end

  def self.currency_for(country)
    COUNTRY_TO_CURRENCY.fetch(country)
  end

  def self.valid?(country)
    COUNTRY_TO_CURRENCY.key?(country)
  end

  def self.bank_field_keys_for(country)
    COUNTRY_BANK_FIELDS.fetch(country) do
      raise KeyError, "unknown country: #{country}"
    end
  end
end
