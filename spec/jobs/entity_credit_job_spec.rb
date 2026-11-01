# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityCreditJob, type: :job do
  include ActiveJob::TestHelper
  include PayrollHelpers

  let(:company) { payroll_company }
  let(:entity) { payroll_entity(company) }
  let(:run) { payroll_run(company, month_on: Date.new(2026, 4, 1)) }

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "creates and credits the entity credit, then enqueues conversion" do
    employee = payroll_employee(entity)
    employee.salary_assignments.create!(effective_on: Date.new(2026, 4, 1), amount_minor: 3_000_00)

    expect { described_class.perform_now(run.id, entity.id) }
      .to change(Payslip, :count).by(1)
      .and change(EntityCredit.where(payroll_run: run, entity:), :count).by(1)

    expect(EntityCredit.find_by!(payroll_run: run, entity:).status).to eq("credited")
    expect(CurrencyConversionJob).to have_been_enqueued.with(run.id, entity.id)
  end

  it "enqueues the run finisher when the last entity credit completes" do
    other_entity = payroll_entity(company)
    run.entity_credits.create!(entity: other_entity, status: "credited")
    employee = payroll_employee(entity)
    employee.salary_assignments.create!(effective_on: Date.new(2026, 4, 1), amount_minor: 3_000_00)

    described_class.perform_now(run.id, entity.id)

    expect(PayrollRunFinisherJob).to have_been_enqueued.with(run.id)
  end

  it "does not enqueue the run finisher while sibling entity credits are incomplete" do
    payroll_entity(company)
    employee = payroll_employee(entity)
    employee.salary_assignments.create!(effective_on: Date.new(2026, 4, 1), amount_minor: 3_000_00)

    described_class.perform_now(run.id, entity.id)

    expect(PayrollRunFinisherJob).not_to have_been_enqueued
  end

  it "does nothing except close credit and enqueue conversion for an empty entity" do
    expect { described_class.perform_now(run.id, entity.id) }
      .to change(EntityCredit.where(payroll_run: run, entity:), :count).by(1)

    expect(EntityCredit.find_by!(payroll_run: run, entity:).status).to eq("credited")
    expect(Payslip.where(payroll_run: run, entity:)).to be_empty
    expect(PayrollSkip.where(payroll_run: run, entity:)).to be_empty
    expect(CurrencyConversionJob).to have_been_enqueued.with(run.id, entity.id)
  end

  it "does not duplicate payslips, skips, or conversion jobs when credit already finished" do
    salaried = payroll_employee(entity, name: "Salaried")
    skipped = payroll_employee(entity, name: "Skipped")
    salaried.salary_assignments.create!(effective_on: Date.new(2026, 4, 1), amount_minor: 3_000_00)

    described_class.perform_now(run.id, entity.id)
    clear_enqueued_jobs

    expect { described_class.perform_now(run.id, entity.id) }
      .not_to change { Payslip.count + PayrollSkip.count + EntityCredit.count }
    expect(CurrencyConversionJob).not_to have_been_enqueued
    expect(Payslip.where(employee: salaried).count).to eq(1)
    expect(PayrollSkip.where(employee: skipped).count).to eq(1)
  end
end
