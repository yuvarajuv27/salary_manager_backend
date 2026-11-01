# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayrollSchedulerJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers
  include PayrollHelpers

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "does not credit the month skipped during Get started" do
    travel_to Time.utc(2026, 3, 31, 12, 0, 0) do
      company = payroll_company(next_payroll_on: Date.new(2026, 4, 30))
      entity = payroll_entity(company)
      employee = payroll_employee(entity, start_on: Date.new(2026, 3, 1))
      employee.salary_assignments.create!(effective_on: Date.new(2026, 3, 1), amount_minor: 3_000_00)

      perform_enqueued_jobs { described_class.perform_later }

      expect(company.payroll_runs).to be_empty
      expect(Payslip.where(employee:)).to be_empty
    end
  end

  it "leaves the frozen payroll date when payroll_day changes before wake" do
    travel_to Time.utc(2026, 4, 30, 1, 0, 0) do
      company = payroll_company(payroll_day: 15, next_payroll_on: Date.new(2026, 4, 30))
      entity = payroll_entity(company)
      payroll_employee(entity).salary_assignments.create!(
        effective_on: Date.new(2026, 4, 1),
        amount_minor: 3_000_00
      )

      perform_enqueued_jobs { described_class.perform_later }

      run = company.payroll_runs.find_by!(month_on: Date.new(2026, 4, 1))
      expect(run.payroll_on).to eq(Date.new(2026, 4, 30))
      expect(company.reload.next_payroll_on).to eq(Date.new(2026, 5, 15))
    end
  end

  it "wakes after downtime and credits the open month once" do
    travel_to Time.utc(2026, 5, 2, 8, 0, 0) do
      company = payroll_company(next_payroll_on: Date.new(2026, 4, 30))
      entity = payroll_entity(company)
      payroll_employee(entity).salary_assignments.create!(
        effective_on: Date.new(2026, 4, 1),
        amount_minor: 3_000_00
      )

      expect do
        perform_enqueued_jobs { described_class.perform_later }
        perform_enqueued_jobs { described_class.perform_later }
      end.to change(PayrollRun, :count).by(1)
        .and change(Payslip, :count).by(1)

      expect(company.payroll_runs.find_by!(month_on: Date.new(2026, 4, 1)).status).to eq("credited")
    end
  end

  it "only enqueues unfinished entity credits when a processing run already exists" do
    travel_to Time.utc(2026, 4, 30, 1, 0, 0) do
      company = payroll_company(next_payroll_on: Date.new(2026, 4, 30))
      credited_entity = payroll_entity(company)
      unfinished_entity = payroll_entity(company)
      run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
      run.entity_credits.create!(entity: credited_entity, status: "credited")

      described_class.perform_now

      expect(EntityCreditJob).not_to have_been_enqueued.with(run.id, credited_entity.id)
      expect(EntityCreditJob).to have_been_enqueued.with(run.id, unfinished_entity.id)
    end
  end

  it "does not enqueue the finisher from the scheduler before entity credits complete" do
    travel_to Time.utc(2026, 4, 30, 1, 0, 0) do
      company = payroll_company(next_payroll_on: Date.new(2026, 4, 30))
      entity = payroll_entity(company)
      payroll_employee(entity).salary_assignments.create!(
        effective_on: Date.new(2026, 4, 1),
        amount_minor: 3_000_00
      )

      described_class.perform_now

      run = company.payroll_runs.find_by!(month_on: Date.new(2026, 4, 1))
      expect(EntityCreditJob).to have_been_enqueued.with(run.id, entity.id)
      expect(PayrollRunFinisherJob).not_to have_been_enqueued
    end
  end

  it "advances next month only after every entity credit is complete" do
    travel_to Time.utc(2026, 4, 30, 1, 0, 0) do
      company = payroll_company(next_payroll_on: Date.new(2026, 4, 30))
      first_entity = payroll_entity(company)
      second_entity = payroll_entity(company)
      run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
      run.entity_credits.create!(entity: first_entity, status: "credited")
      run.entity_credits.create!(entity: second_entity, status: "processing")

      PayrollRunFinisherJob.perform_now(run.id)
      expect(run.reload.status).to eq("processing")
      expect(company.reload.next_payroll_on).to eq(Date.new(2026, 4, 30))

      run.entity_credits.find_by!(entity: second_entity).update!(status: "credited")
      PayrollRunFinisherJob.perform_now(run.id)

      expect(run.reload.status).to eq("credited")
      expect(company.reload.next_payroll_on).to eq(Date.new(2026, 5, 31))
    end
  end

  it "enqueues pending currency conversions on wake" do
    company = payroll_company(next_payroll_on: Date.new(2026, 5, 31))
    entity = payroll_entity(company, country: "France")
    run = payroll_run(company, month_on: Date.new(2026, 4, 1), payroll_on: Date.new(2026, 4, 30))
    run.currency_conversions.create!(entity:, status: "pending", primary_currency: "USD")

    described_class.perform_now

    expect(CurrencyConversionJob).to have_been_enqueued.with(run.id, entity.id)
  end
end
