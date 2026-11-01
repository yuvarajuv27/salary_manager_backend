# frozen_string_literal: true

class PayrollSchedulerJob < ApplicationJob
  ENTITY_BATCH_SIZE = 50

  def perform
    Company.includes(:entities).find_each do |company|
      schedule_company(company) if due?(company)
    end
    enqueue_pending_conversions
  end

  private

  def due?(company)
    company.entities.any? && Time.now.utc.to_date >= company.next_payroll_on
  end

  def schedule_company(company)
    run = find_or_open_run(company)
    return if run.status == "credited"

    unfinished_entities(run).each_slice(ENTITY_BATCH_SIZE) do |entities|
      ActiveJob.perform_all_later(
        entities.map { |entity| EntityCreditJob.new(run.id, entity.id) }
      )
    end
  end

  def find_or_open_run(company)
    payroll_on = company.next_payroll_on
    period_start_on, period_end_on = PayrollCalendar.period_bounds_for(company, payroll_on)

    company.payroll_runs.find_or_create_by!(month_on: period_start_on) do |run|
      run.payroll_on = payroll_on
      run.period_start_on = period_start_on
      run.period_end_on = period_end_on
      run.primary_currency = company.primary_currency
      run.status = "processing"
    end
  end

  def unfinished_entities(run)
    credited_entity_ids = run.entity_credits.where(status: "credited").select(:entity_id)
    run.company.entities.where.not(id: credited_entity_ids)
  end

  def enqueue_pending_conversions
    CurrencyConversion.where(status: "pending").find_each do |conversion|
      CurrencyConversionJob.perform_later(conversion.payroll_run_id, conversion.entity_id)
    end
  end
end
