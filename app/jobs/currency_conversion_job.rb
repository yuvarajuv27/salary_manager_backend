# frozen_string_literal: true

class CurrencyConversionJob < ApplicationJob
  class_attribute :client, default: FrankfurterClient.new

  def perform(payroll_run_id, entity_id)
    run = PayrollRun.find(payroll_run_id)
    entity = Entity.find(entity_id)
    conversion = find_or_initialize_conversion(run, entity)
    return if conversion.persisted? && conversion.status == "stored"

    if entity.currency == run.primary_currency
      store_conversion(conversion, rate: BigDecimal("1"), rate_on: run.payroll_on)
      return
    end

    rate = client.rate_on(date: run.payroll_on, from: entity.currency, to: run.primary_currency)
    store_conversion(conversion, rate: rate_value(rate), rate_on: rate_date(rate))
  rescue StandardError
    mark_pending(run, entity)
  end

  private

  def find_or_initialize_conversion(run, entity)
    run.currency_conversions.find_or_initialize_by(entity:) do |conversion|
      conversion.primary_currency = run.primary_currency
    end
  end

  def store_conversion(conversion, rate:, rate_on:)
    totals = payslip_totals(conversion.payroll_run, conversion.entity)
    conversion.update!(
      status: "stored",
      rate:,
      rate_on:,
      primary_currency: conversion.payroll_run.primary_currency,
      gross_minor: convert(totals.fetch(:gross_minor), rate, conversion.entity.currency, conversion.payroll_run.primary_currency),
      net_minor: convert(totals.fetch(:net_minor), rate, conversion.entity.currency, conversion.payroll_run.primary_currency),
      employer_cost_minor: convert(totals.fetch(:employer_cost_minor), rate, conversion.entity.currency, conversion.payroll_run.primary_currency)
    )
  end

  def payslip_totals(run, entity)
    run.payslips.where(entity:).pick(
      Arel.sql("COALESCE(SUM(gross_minor), 0)"),
      Arel.sql("COALESCE(SUM(net_minor), 0)"),
      Arel.sql("COALESCE(SUM(employer_cost_minor), 0)")
    ).then do |gross_minor, net_minor, employer_cost_minor|
      { gross_minor:, net_minor:, employer_cost_minor: }
    end
  end

  def convert(amount_minor, rate, from_currency, to_currency)
    source_major = amount_minor.to_r / (10**MoneyRounding::EXPONENTS.fetch(from_currency))
    MoneyRounding.round_half_away_from_zero(source_major * BigDecimal(rate.to_s).to_r, to_currency)
  end

  def rate_value(rate)
    rate.respond_to?(:rate) ? rate.rate : rate.fetch(:rate)
  end

  def rate_date(rate)
    rate.respond_to?(:date) ? rate.date : rate.fetch(:date)
  end

  def mark_pending(run, entity)
    conversion = find_or_initialize_conversion(run, entity)
    conversion.update!(
      status: "pending",
      rate: nil,
      rate_on: nil,
      primary_currency: run.primary_currency,
      gross_minor: nil,
      net_minor: nil,
      employer_cost_minor: nil
    )
  end
end
