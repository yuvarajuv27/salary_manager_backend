# frozen_string_literal: true

class PayrollRunFinisherJob < ApplicationJob
  def perform(payroll_run_id)
    run = PayrollRun.includes(:company, :entity_credits).find(payroll_run_id)
    return if run.status == "credited"
    return unless run.entity_credits.size == run.company.entities.count
    return unless run.entity_credits.all? { |credit| credit.status == "credited" }

    PayrollRun.transaction do
      run.update!(status: "credited")
      run.company.update!(
        next_payroll_on: PayrollCalendar.next_payroll_after(run.company, run.payroll_on)
      )
    end
  end
end
