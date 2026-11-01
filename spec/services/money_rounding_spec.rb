# frozen_string_literal: true

require "rails_helper"

RSpec.describe MoneyRounding do
  describe ".round_half_away_from_zero" do
    it "rounds half cents away from zero for USD minor units" do
      expect(described_class.round_half_away_from_zero(Rational(1005, 1000), "USD")).to eq(101)
      expect(described_class.round_half_away_from_zero(Rational(-1005, 1000), "USD")).to eq(-101)
    end

    it "rounds JPY to whole yen" do
      expect(described_class.round_half_away_from_zero(Rational(1005, 10), "JPY")).to eq(101)
    end
  end
end
