# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payslip immutability", type: :request do
  include PayrollHelpers
  include ActiveSupport::Testing::TimeHelpers

  def json
    response.parsed_body
  end

  def credit_entity!(entity, month_on: Date.new(2026, 3, 1))
    company = entity.company
    run = payroll_run(company, month_on:, status: "credited")
    run.entity_credits.create!(company:, entity:, status: "credited")
    run
  end

  around do |example|
    travel_to Time.utc(2026, 3, 15, 12, 0, 0) do
      example.run
    end
  end

  before { sign_up_admin! }

  it "keeps a credited payslip unchanged after salary, leave, and rule edits" do
    entity = create_entity!
    employee = create_employee!(entity:, start_on: "2026-01-01")
    employee.salary_assignments.create!(
      company: employee.company,
      effective_on: Date.new(2026, 3, 1),
      amount_minor: 5_000_00
    )
    rule = entity.pay_rules.create!(
      name: "Tax", position: 0, side: "employee_deduction", kind: "percent", percent: 10
    )
    run = credit_entity!(entity)
    payslip = payslip_for(
      run:, employee:,
      gross_minor: 5_000_00, net_minor: 4_500_00, employer_cost_minor: 5_000_00,
      lines: [{ "name" => "Tax", "computed_minor" => 500_00 }]
    )
    snapshot = payslip.reload.attributes.slice(
      "gross_minor", "net_minor", "employer_cost_minor", "lines", "payable_days"
    )

    put "/entities/#{entity.id}/employees/#{employee.id}/salary",
        params: { amount_minor: 9_000_00 }, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    post "/entities/#{entity.id}/employees/#{employee.id}/leave_days",
         params: { leave_on: "2026-03-10" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    patch "/entities/#{entity.id}/pay_rules/#{rule.id}",
          params: { percent: "20.0000" }, as: :json
    expect(response).to have_http_status(:ok)

    expect(payslip.reload.attributes.slice(
      "gross_minor", "net_minor", "employer_cost_minor", "lines", "payable_days"
    )).to eq(snapshot)
  end

  describe "delete guards" do
    it "refuses to delete an employee who has a payslip" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = credit_entity!(entity)
      payslip_for(run:, employee:)

      delete "/entities/#{entity.id}/employees/#{employee.id}", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["base"]).to be_present
    end

    it "refuses to delete an entity that has a payslip" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = credit_entity!(entity)
      payslip_for(run:, employee:)

      delete "/entities/#{entity.id}", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["base"]).to be_present
    end
  end
end
