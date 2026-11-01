# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entities API", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include PayrollHelpers

  def json
    response.parsed_body
  end

  before { sign_up_admin! }

  describe "POST /entities" do
    it "creates an entity with currency from country" do
      expect do
        post "/entities", params: { name: "US Ops", country: "United States" }, as: :json
      end.to change(Entity, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include(
        "name" => "US Ops",
        "country" => "United States",
        "currency" => "USD"
      )
    end

    it "advances next_payroll_on on first entity when the stored date is in the past" do
      company = Company.last
      travel_to Time.utc(2026, 4, 10, 12, 0, 0) do
        company.update!(next_payroll_on: Date.new(2026, 3, 31), payroll_day: 31)

        post "/entities", params: { name: "First Entity", country: "India" }, as: :json

        expect(response).to have_http_status(:created)
        expect(company.reload.next_payroll_on).to eq(Date.new(2026, 4, 30))
      end
    end

    it "does not advance next_payroll_on on second entity create" do
      create_entity!
      company = Company.last

      travel_to Time.utc(2026, 4, 10, 12, 0, 0) do
        past_date = Date.new(2026, 3, 31)
        company.update!(next_payroll_on: past_date)

        post "/entities", params: { name: "Second", country: "Canada" }, as: :json

        expect(response).to have_http_status(:created)
        expect(company.reload.next_payroll_on).to eq(past_date)
      end
    end

    it "returns 422 for invalid country" do
      post "/entities", params: { name: "Bad", country: "Narnia" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["country"]).to be_present
    end
  end

  describe "GET /entities" do
    it "lists all entities for admin" do
      create_entity!(name: "A")
      create_entity!(name: "B", country: "Canada")

      get "/entities", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.map { |e| e["name"] }).to contain_exactly("A", "B")
    end

    it "returns only the HR user's entity" do
      entity_a = create_entity!(name: "Mine")
      create_entity!(name: "Other", country: "Canada")
      create_hr_user!(admin_company: Company.last, entity: entity_a, email: "hr@example.com")

      delete "/session", as: :json
      sign_in_via_api(email: "hr@example.com", password: "password123")

      get "/entities", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.size).to eq(1)
      expect(json.first["id"]).to eq(entity_a.id)
    end
  end

  describe "GET /entities/:id" do
    it "returns one entity for admin" do
      entity = create_entity!

      get "/entities/#{entity.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(entity.id)
    end
  end

  describe "PATCH /entities/:id" do
    it "renames an entity" do
      entity = create_entity!

      patch "/entities/#{entity.id}", params: { name: "Renamed" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["name"]).to eq("Renamed")
    end

    it "updates country and currency for admin before payslips" do
      entity = create_entity!(country: "United States")

      patch "/entities/#{entity.id}", params: { country: "India" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["country"]).to eq("India")
      expect(json["currency"]).to eq("INR")
    end

    it "requires a complete bank set for every employee on country change" do
      entity = create_entity!(country: "United States")
      employee = create_employee!(entity:)

      patch "/entities/#{entity.id}", params: { country: "India" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["employee_banks"]).to be_present
      expect(entity.reload.country).to eq("United States")
      expect(employee.reload.bank_details_hash["routing_number"]).to eq("021000021")
    end

    it "replaces every employee bank set when the country changes" do
      entity = create_entity!(country: "United States")
      employee = create_employee!(entity:)

      patch "/entities/#{entity.id}", params: {
        country: "India",
        employee_banks: [
          { employee_id: employee.id, bank_details: india_bank_details }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["country"]).to eq("India")
      expect(employee.reload.bank_details_hash["ifsc"]).to eq("HDFC0001234")
    end
  end

  describe "DELETE /entities/:id" do
    it "deletes an entity with no payslips" do
      entity = create_entity!

      expect do
        delete "/entities/#{entity.id}", as: :json
      end.to change(Entity, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "deletes an entity with only payroll skips and removes the skips" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = payroll_run(Company.last, month_on: Date.new(2026, 3, 1))
      payroll_skip_for(run:, employee:)

      expect do
        delete "/entities/#{entity.id}", as: :json
      end.to change(Entity, :count).by(-1)
        .and change(PayrollSkip, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 422 when the entity has a payslip" do
      entity = create_entity!
      employee = create_employee!(entity:)
      run = payroll_run(Company.last, month_on: Date.new(2026, 3, 1))
      payslip_for(run:, employee:)

      delete "/entities/#{entity.id}", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["base"]).to be_present
    end
  end
end
