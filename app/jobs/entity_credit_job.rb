# frozen_string_literal: true

class EntityCreditJob < ApplicationJob
  retry_on StandardError, attempts: 5, wait: :polynomially_longer

  def perform(payroll_run_id, entity_id)
    run = PayrollRun.find(payroll_run_id)
    entity = Entity.find(entity_id)

    credit = EntityCredit.find_or_create_by!(payroll_run: run, entity:) do |entity_credit|
      entity_credit.status = "processing"
    end
    return if credit.status == "credited"

    EntityCredit.transaction do
      PayslipBuilder.call(run:, entity:)
      credit.update!(status: "credited")
    end

    CurrencyConversionJob.perform_later(run.id, entity.id)
    PayrollRunFinisherJob.perform_later(run.id) if all_entity_credits_complete?(run)
  end

  private

  def all_entity_credits_complete?(run)
    run.reload
    return false unless run.entity_credits.count == run.company.entities.count

    run.entity_credits.where.not(status: "credited").none?
  end
end
