# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payroll runs API", type: :request do
  include PayrollHelpers

  def json
    response.parsed_body
  end

  def credit_entity!(entity, month_on: Date.new(2026, 3, 1))
    company = entity.company
    run = payroll_run(company, month_on:, status: "credited")
    run.entity_credits.create!(company:, entity:, status: "credited")
    run
  end

  before { sign_up_admin! }

  describe "GET /entities/:entity_id/payroll_runs" do
    it "lists credited months for the entity" do
      entity = create_entity!
      credit_entity!(entity, month_on: Date.new(2026, 2, 1))
      credit_entity!(entity, month_on: Date.new(2026, 3, 1))

      get "/entities/#{entity.id}/payroll_runs", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.pluck("month_on")).to eq(%w[2026-02-01 2026-03-01])
    end

    it "omits months where the entity credit is not finished" do
      entity = create_entity!
      company = entity.company
      run = payroll_run(company, month_on: Date.new(2026, 4, 1))
      run.entity_credits.create!(company:, entity:, status: "processing")

      get "/entities/#{entity.id}/payroll_runs", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end
  end

  describe "GET /entities/:entity_id/payroll_runs/:month" do
    it "returns payslips and skips for the month" do
      entity = create_entity!
      employee = create_employee!(entity:)
      skipped = create_employee!(entity:, name: "Sam")
      run = credit_entity!(entity)
      payslip = payslip_for(run:, employee:)
      payroll_skip_for(run:, employee: skipped)

      get "/entities/#{entity.id}/payroll_runs/2026-03-01", as: :json

      expect(response).to have_http_status(:ok)
      expect(json["month_on"]).to eq("2026-03-01")
      expect(json["entries"]).to contain_exactly(
        hash_including("type" => "payslip", "payslip_id" => payslip.id, "employee_name" => "Alex"),
        hash_including("type" => "skip", "reason" => "monthly_salary_unset", "employee_name" => "Sam")
      )
    end
  end
end
