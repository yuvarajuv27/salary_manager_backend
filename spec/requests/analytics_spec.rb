# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analytics API", type: :request do
  include PayrollHelpers

  def json
    response.parsed_body
  end

  def credit_entity!(entity, month_on: Date.new(2026, 3, 1))
    run = payroll_run(entity.company, month_on:, status: "credited")
    run.entity_credits.create!(company: entity.company, entity:, status: "credited")
    run
  end

  def stored_conversion!(run:, entity:, **attrs)
    run.currency_conversions.create!({
      company: run.company,
      entity:,
      status: "stored",
      primary_currency: run.primary_currency,
      rate: 1,
      rate_on: run.payroll_on,
      gross_minor: 5_000_00,
      net_minor: 4_500_00,
      employer_cost_minor: 5_500_00
    }.merge(attrs))
  end

  before { sign_up_admin! }

  describe "GET /entities/:entity_id/analytics" do
    it "returns entity analytics for admin" do
      entity = create_entity!
      run = credit_entity!(entity)
      payslip_for(run:, employee: create_employee!(entity:))

      get "/entities/#{entity.id}/analytics", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "currency" => entity.currency,
        "empty" => false,
        "latest" => hash_including("month_on" => "2026-03-01", "headcount" => 1),
        "series" => [hash_including("month_on" => "2026-03-01")],
        "rule_totals" => []
      )
    end

    it "returns empty analytics before the first credit" do
      entity = create_entity!

      get "/entities/#{entity.id}/analytics", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("empty" => true, "latest" => nil, "series" => [])
    end

    it "allows HR for their entity and hides other entities" do
      admin = User.find_by!(email: "jane@example.com")
      entity_a = create_entity!(name: "Entity A")
      entity_b = create_entity!(name: "Entity B", country: "Canada")
      create_hr_user!(admin_company: admin.company, entity: entity_a, email: "hr@example.com")

      delete "/session", as: :json
      sign_in_via_api(email: "hr@example.com", password: "password123")

      get "/entities/#{entity_a.id}/analytics", as: :json
      expect(response).to have_http_status(:ok)

      get "/entities/#{entity_b.id}/analytics", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /analytics" do
    it "returns account analytics for admin" do
      entity = create_entity!
      run = credit_entity!(entity)
      payslip_for(run:, employee: create_employee!(entity:))
      stored_conversion!(run:, entity:)

      get "/analytics", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "currency" => "USD",
        "empty" => false,
        "pending_entity_names" => [],
        "employer_cost_by_entity" => [
          hash_including("entity_id" => entity.id, "employer_cost_minor" => 5_500_00)
        ]
      )
    end

    it "returns 404 for HR" do
      admin = User.find_by!(email: "jane@example.com")
      entity = create_entity!
      create_hr_user!(admin_company: admin.company, entity:, email: "hr@example.com")

      delete "/session", as: :json
      sign_in_via_api(email: "hr@example.com", password: "password123")

      get "/analytics", as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
