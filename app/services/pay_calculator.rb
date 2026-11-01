# frozen_string_literal: true

require "ostruct"

class PayCalculator
  class InvalidEarnings < StandardError; end

  def self.call(rules:, gross_minor:, currency:, mode: :preview)
    new(rules:, gross_minor:, currency:, mode:).call
  end

  def initialize(rules:, gross_minor:, currency:, mode:)
    @rules = rules.sort_by { |rule| value_for(rule, :position) }
    @gross_minor = Integer(gross_minor)
    @currency = currency
    @mode = mode.to_sym
  end

  def call
    deductions = rules_for("employee_deduction").map { |rule| line_for(rule) }
    employer_contributions = rules_for("employer_contribution").map { |rule| line_for(rule) }

    OpenStruct.new(
      earnings: earning_lines,
      deductions:,
      employer_contributions:,
      net_minor: [gross_minor - deductions.sum(&:computed_minor), 0].max,
      employer_cost_minor: gross_minor + employer_contributions.sum(&:computed_minor)
    )
  end

  private

  attr_reader :rules, :gross_minor, :currency, :mode

  def earning_lines
    earnings = rules_for("earning")
    return [] if earnings.empty?

    unless earnings_percent_total_valid?(earnings)
      raise InvalidEarnings if mode == :preview

      return []
    end

    earlier_total = 0
    earnings.each_with_index.map do |rule, index|
      computed_minor =
        if index == earnings.length - 1
          gross_minor - earlier_total
        else
          rounded_percent_amount(gross_minor, value_for(rule, :percent))
        end
      earlier_total += computed_minor
      line_for(rule, computed_minor:)
    end
  end

  def rules_for(side)
    rules.select { |rule| value_for(rule, :side) == side }
  end

  def earnings_percent_total_valid?(earnings)
    earnings.sum { |rule| BigDecimal(value_for(rule, :percent).to_s) } == BigDecimal("100")
  end

  def line_for(rule, computed_minor: computed_minor_for(rule))
    OpenStruct.new(
      position: value_for(rule, :position),
      name: value_for(rule, :name),
      side: value_for(rule, :side),
      kind: value_for(rule, :kind),
      percent: formatted_percent(value_for(rule, :percent)),
      amount_minor: value_for(rule, :amount_minor),
      ceiling_minor: value_for(rule, :ceiling_minor),
      computed_minor:
    )
  end

  def computed_minor_for(rule)
    case value_for(rule, :kind)
    when "fixed"
      Integer(value_for(rule, :amount_minor))
    when "percent"
      base_minor = [gross_minor, value_for(rule, :ceiling_minor)].compact.min
      rounded_percent_amount(base_minor, value_for(rule, :percent))
    end
  end

  def rounded_percent_amount(base_minor, percent)
    major_amount = Rational(base_minor) * BigDecimal(percent.to_s).to_r / 100 / minor_unit_factor
    MoneyRounding.round_half_away_from_zero(major_amount, currency)
  end

  def minor_unit_factor
    10**MoneyRounding::EXPONENTS.fetch(currency)
  end

  def formatted_percent(percent)
    return nil if percent.nil?

    format("%.4f", BigDecimal(percent.to_s))
  end

  def value_for(rule, attribute)
    if rule.respond_to?(attribute)
      rule.public_send(attribute)
    elsif rule.is_a?(Hash)
      rule[attribute] || rule[attribute.to_s]
    else
      rule.fetch(attribute)
    end
  end
end
