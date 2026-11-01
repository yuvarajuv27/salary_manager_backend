# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Company API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def json
    response.parsed_body
  end

  before { sign_up_admin! }

  describe "GET /company" do
    it "returns the admin company" do
      company = Company.last

      get "/company", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "id" => company.id,
        "legal_name" => "Acme Corp",
        "primary_currency" => "USD",
        "pay_frequency" => "monthly",
        "payroll_day" => 31,
        "pay_weekday" => nil,
        "biweekly_anchor_on" => nil,
        "next_payroll_on" => company.next_payroll_on.iso8601
      )
    end
  end

  describe "PATCH /company" do
    it "updates legal name and primary currency" do
      patch "/company", params: { legal_name: "Acme International", primary_currency: "EUR" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["legal_name"]).to eq("Acme International")
      expect(json["primary_currency"]).to eq("EUR")
      expect(Company.last.legal_name).to eq("Acme International")
    end

    it "does not change next_payroll_on when payroll_day is patched" do
      company = Company.last
      original_next = company.next_payroll_on

      patch "/company", params: { payroll_day: 15 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["payroll_day"]).to eq(15)
      expect(json["next_payroll_on"]).to eq(original_next.iso8601)
      expect(company.reload.next_payroll_on).to eq(original_next)
    end

    it "returns 422 for invalid primary currency" do
      patch "/company", params: { primary_currency: "XYZ" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["primary_currency"]).to be_present
    end
  end
end
