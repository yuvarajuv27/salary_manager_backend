# frozen_string_literal: true

class MoneyRounding
  EXPONENTS = {
    "INR" => 2,
    "USD" => 2,
    "GBP" => 2,
    "CAD" => 2,
    "JPY" => 0,
    "AUD" => 2,
    "SGD" => 2,
    "EUR" => 2
  }.freeze

  def self.round_half_away_from_zero(rational_or_numeric, currency)
    new(rational_or_numeric, currency).round_half_away_from_zero
  end

  def initialize(rational_or_numeric, currency)
    @amount = rational_or_numeric
    @currency = currency
  end

  def round_half_away_from_zero
    scaled_amount = to_rational(amount) * minor_unit_factor
    sign = scaled_amount.negative? ? -1 : 1
    absolute = scaled_amount.abs

    sign * (absolute.floor + (absolute - absolute.floor >= Rational(1, 2) ? 1 : 0))
  end

  private

  attr_reader :amount, :currency

  def minor_unit_factor
    10**EXPONENTS.fetch(currency)
  end

  def to_rational(value)
    return value if value.is_a?(Rational)
    return value.to_r if value.respond_to?(:to_r)

    BigDecimal(value.to_s).to_r
  end
end
