# frozen_string_literal: true

module Analytics
  class EntityAnalytics
    SERIES_LIMIT = 12
    RULE_SIDES = %w[employee_deduction employer_contribution].freeze

    def self.call(entity:)
      new(entity:).call
    end

    def initialize(entity:)
      @entity = entity
    end

    def call
      credits = credited_credits
      return empty_payload if credits.empty?

      latest_run = credits.last.payroll_run
      latest_payslips = payslips_for(latest_run)

      {
        currency: entity.currency,
        latest: month_snapshot(latest_run, latest_payslips),
        series: series_for(credits),
        rule_totals: RuleTotals.from_payslips(latest_payslips),
        empty: false
      }
    end

    private

    attr_reader :entity

    def credited_credits
      entity.entity_credits
        .where(status: "credited")
        .joins(:payroll_run)
        .order("payroll_runs.month_on")
        .includes(:payroll_run)
    end

    def payslips_for(run)
      run.payslips.where(entity_id: entity.id)
    end

    def empty_payload
      {
        currency: entity.currency,
        latest: nil,
        series: [],
        rule_totals: [],
        empty: true
      }
    end

    def month_snapshot(run, payslips)
      {
        month_on: run.month_on,
        headcount: payslips.count,
        gross_minor: payslips.sum(:gross_minor),
        net_minor: payslips.sum(:net_minor),
        employer_cost_minor: payslips.sum(:employer_cost_minor)
      }
    end

    def series_for(credits)
      credits.last(SERIES_LIMIT).map do |credit|
        payslips = payslips_for(credit.payroll_run)
        {
          month_on: credit.payroll_run.month_on,
          gross_minor: payslips.sum(:gross_minor),
          net_minor: payslips.sum(:net_minor),
          employer_cost_minor: payslips.sum(:employer_cost_minor)
        }
      end
    end
  end
end
