# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Employees API", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include PayrollHelpers

  def json
    response.parsed_body
  end

  before { sign_up_admin! }

  describe "GET /entities/:entity_id/employees" do
    it "returns a paginated payload with defaults" do
      entity = create_entity!
      3.times do |index|
        create_employee!(entity:, name: "Worker #{index}", bank_details: us_bank_details)
      end

      get "/entities/#{entity.id}/employees"

      expect(response).to have_http_status(:ok)
      expect(json["employees"].length).to eq(3)
      expect(json["page"]).to eq(1)
      expect(json["per_page"]).to eq(50)
      expect(json["total"]).to eq(3)
      expect(json["total_pages"]).to eq(1)
    end

    it "filters by name and respects page size" do
      entity = create_entity!
      create_employee!(entity:, name: "Alice Alpha", bank_details: us_bank_details)
      create_employee!(entity:, name: "Bob Beta", bank_details: us_bank_details)
      create_employee!(entity:, name: "Alice Gamma", bank_details: us_bank_details)

      get "/entities/#{entity.id}/employees", params: { q: "alice", page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json["total"]).to eq(2)
      expect(json["total_pages"]).to eq(2)
      expect(json["employees"].length).to eq(1)
      expect(json["employees"].first["name"]).to match(/Alice/i)
    end
  end

  describe "POST /entities/:entity_id/employees" do
    it "creates an employee with masked bank details in the response" do
      entity = create_entity!

      post "/entities/#{entity.id}/employees", params: {
        name: "Alex",
        job_role: "Analyst",
        department: "Finance",
        start_on: "2026-01-01",
        bank_details: us_bank_details
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["bank_details"]).to include(
        "account_holder_name" => "Jane Doe",
        "account_number" => "7890",
        "routing_number" => "0021"
      )
    end

    it "returns 422 for a partial bank set" do
      entity = create_entity!

      post "/entities/#{entity.id}/employees", params: {
        name: "Alex",
        job_role: "Analyst",
        department: "Finance",
        start_on: "2026-01-01",
        bank_details: { account_holder_name: "Jane Doe" }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["bank_payload"]).to be_present
    end
  end

  describe "GET /entities/:entity_id/employees/:employee_id" do
    it "returns readable false when bank decryption fails" do
      entity = create_entity!
      employee = create_employee!(entity:)
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(
          ["UPDATE employees SET bank_payload = ? WHERE id = ?", "not-valid-ciphertext", employee.id]
        )
      )

      get "/entities/#{entity.id}/employees/#{employee.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json["bank_details"]).to eq("readable" => false)
      expect(json["name"]).to eq("Alex")
    end
  end

  describe "DELETE /entities/:entity_id/employees/:employee_id" do
    it "deletes an employee with no payslip" do
      entity = create_entity!
      employee = create_employee!(entity:)

      expect do
        delete "/entities/#{entity.id}/employees/#{employee.id}", as: :json
      end.to change(Employee, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "deletes an employee with only payroll skips and removes the skips" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = payroll_run(Company.last, month_on: Date.new(2026, 3, 1))
      payroll_skip_for(run:, employee:)

      expect do
        delete "/entities/#{entity.id}/employees/#{employee.id}", as: :json
      end.to change(Employee, :count).by(-1)
        .and change(PayrollSkip, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 422 when the employee has a payslip" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = payroll_run(Company.last, month_on: Date.new(2026, 3, 1))
      payslip_for(run:, employee:)

      delete "/entities/#{entity.id}/employees/#{employee.id}", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["base"]).to be_present
    end
  end

  describe "PUT salary endpoints" do
    it "writes a correction for the open month" do
      entity = create_entity!
      employee = create_employee!(entity:)

      put "/entities/#{entity.id}/employees/#{employee.id}/salary",
          params: { amount_minor: 500_000 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["amount_minor"]).to eq(500_000)
      expect(json["effective_on"]).to eq(Company.last.next_payroll_on.beginning_of_month.iso8601)
    end

    it "writes a revision for the first day of the next calendar month" do
      entity = create_entity!
      employee = create_employee!(entity:)

      travel_to Date.new(2026, 3, 15) do
        put "/entities/#{entity.id}/employees/#{employee.id}/salary_revision",
            params: { amount_minor: 600_000 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json["effective_on"]).to eq(Date.new(2026, 4, 1).iso8601)
      end
    end
  end

  describe "leave days" do
    it "lists and adds leave inside employment" do
      entity = create_entity!
      employee = create_employee!(entity:)

      post "/entities/#{entity.id}/employees/#{employee.id}/leave_days",
           params: { leave_on: "2026-02-10" }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["leave_on"]).to eq("2026-02-10")

      get "/entities/#{entity.id}/employees/#{employee.id}/leave_days", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.map { |row| row["leave_on"] }).to eq(["2026-02-10"])
    end

    it "rejects leave outside employment" do
      entity = create_entity!
      employee = create_employee!(entity:)

      post "/entities/#{entity.id}/employees/#{employee.id}/leave_days",
           params: { leave_on: "2025-12-31" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["leave_on"]).to be_present
    end

    it "rejects leave changes in a credited month" do
      entity = create_entity!
      employee = create_employee!(entity:)
      leave_on = Date.new(2026, 2, 10)
      allow(Workforce::CreditedMonth).to receive(:credited?).with(employee, leave_on.beginning_of_month).and_return(true)

      post "/entities/#{entity.id}/employees/#{employee.id}/leave_days",
           params: { leave_on: leave_on.iso8601 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "removes leave outside a credited month" do
      entity = create_entity!
      employee = create_employee!(entity:)
      employee.leave_days.create!(company: employee.company, leave_on: Date.new(2026, 2, 10))

      delete "/entities/#{entity.id}/employees/#{employee.id}/leave_days/2026-02-10", as: :json

      expect(response).to have_http_status(:no_content)
      expect(employee.leave_days.count).to eq(0)
    end
  end
end
