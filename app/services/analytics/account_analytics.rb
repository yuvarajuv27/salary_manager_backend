# frozen_string_literal: true

module Analytics
  class AccountAnalytics
    SERIES_LIMIT = 12

    def self.call(company:)
      new(company:).call
    end

    def initialize(company:)
      @company = company
    end

    def call
      runs = credited_runs
      return empty_payload if runs.empty?

      latest_run = runs.last
      stored = stored_conversions_for(latest_run)
      pending = pending_conversions_for(latest_run)

      {
        currency: latest_run.primary_currency,
        latest: latest_snapshot(latest_run, stored),
        series: series_for(runs),
        rule_totals: RuleTotals.from_stored_conversions(latest_run, stored),
        employer_cost_by_entity: employer_cost_by_entity(stored),
        pending_entity_names: pending.map { |conversion| conversion.entity.name }.sort,
        empty: false
      }
    end

    private

    attr_reader :company

    def credited_runs
      company.payroll_runs.where(status: "credited").order(:month_on)
    end

    def stored_conversions_for(run)
      run.currency_conversions.where(status: "stored").includes(:entity).order(:entity_id)
    end

    def pending_conversions_for(run)
      run.currency_conversions.where(status: "pending").includes(:entity).order(:entity_id)
    end

    def empty_payload
      {
        currency: company.primary_currency,
        latest: nil,
        series: [],
        rule_totals: [],
        employer_cost_by_entity: [],
        pending_entity_names: [],
        empty: true
      }
    end

    def latest_snapshot(run, stored)
      {
        month_on: run.month_on,
        headcount: headcount_for(run, stored),
        gross_minor: stored.sum(&:gross_minor),
        net_minor: stored.sum(&:net_minor),
        employer_cost_minor: stored.sum(&:employer_cost_minor)
      }
    end

    def headcount_for(run, stored)
      stored.sum do |conversion|
        run.payslips.where(entity_id: conversion.entity_id).count
      end
    end

    def series_for(runs)
      runs.last(SERIES_LIMIT).map do |run|
        stored = stored_conversions_for(run)
        {
          month_on: run.month_on,
          gross_minor: stored.sum(&:gross_minor),
          net_minor: stored.sum(&:net_minor),
          employer_cost_minor: stored.sum(&:employer_cost_minor)
        }
      end
    end

    def employer_cost_by_entity(stored)
      stored.map do |conversion|
        {
          entity_id: conversion.entity_id,
          name: conversion.entity.name,
          employer_cost_minor: conversion.employer_cost_minor
        }
      end
    end
  end
end
