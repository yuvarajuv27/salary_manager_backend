# frozen_string_literal: true

module Analytics
  module RuleTotals
    RULE_SIDES = EntityAnalytics::RULE_SIDES

    module_function

    def from_payslips(payslips, rate: 1, target_currency: nil)
      totals = Hash.new(0)

      payslips.find_each do |payslip|
        Array(payslip.lines).each do |line|
          side = line["side"]
          next unless RULE_SIDES.include?(side)

          amount = convert(line["computed_minor"].to_i, rate, payslip.currency, target_currency || payslip.currency)
          totals[[line["name"], side]] += amount
        end
      end

      totals.map do |(name, side), amount_minor|
        { name:, side:, amount_minor: }
      end.sort_by { |row| [row[:side], row[:name]] }
    end

    def from_stored_conversions(run, stored_conversions)
      totals = Hash.new(0)

      stored_conversions.each do |conversion|
        payslips = run.payslips.where(entity_id: conversion.entity_id)
        from_payslips(payslips, rate: conversion.rate, target_currency: run.primary_currency).each do |row|
          key = [row[:name], row[:side]]
          totals[key] += row[:amount_minor]
        end
      end

      totals.map do |(name, side), amount_minor|
        { name:, side:, amount_minor: }
      end.sort_by { |row| [row[:side], row[:name]] }
    end

    def convert(amount_minor, rate, from_currency, to_currency)
      source_major = amount_minor.to_r / (10**MoneyRounding::EXPONENTS.fetch(from_currency))
      MoneyRounding.round_half_away_from_zero(source_major * BigDecimal(rate.to_s).to_r, to_currency)
    end
  end
end
