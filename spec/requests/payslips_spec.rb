# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payslips API", type: :request do
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

  describe "GET /entities/:entity_id/payslips/:payslip_id" do
    it "returns stored payslip lines and the employee's current role fields" do
      entity = create_entity!
      employee = create_employee!(entity:, job_role: "Analyst", department: "Finance")
      run = credit_entity!(entity)
      lines = [
        { "position" => 0, "name" => "Base", "side" => "earning", "kind" => "percent",
          "percent" => "100.0000", "amount_minor" => nil, "ceiling_minor" => nil, "computed_minor" => 5_000_00 }
      ]
      payslip = payslip_for(run:, employee:, lines:)

      patch "/entities/#{entity.id}/employees/#{employee.id}",
            params: { job_role: "Lead", department: "Ops" }, as: :json
      expect(response).to have_http_status(:ok)

      get "/entities/#{entity.id}/payslips/#{payslip.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "id" => payslip.id,
        "month_on" => "2026-03-01",
        "job_role" => "Lead",
        "department" => "Ops",
        "gross_minor" => 5_000_00,
        "lines" => lines
      )
      expect(json).not_to have_key("bank_details")
    end
  end
end
