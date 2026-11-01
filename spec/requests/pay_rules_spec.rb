# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pay rules API", type: :request do
  def json
    response.parsed_body
  end

  def pay_rules_path(entity)
    "/entities/#{entity.id}/pay_rules"
  end

  def pay_rule_path(entity, rule)
    "/entities/#{entity.id}/pay_rules/#{rule.id}"
  end

  def fr19_rules
    [
      {
        name: "Tax",
        position: 0,
        side: "employee_deduction",
        kind: "percent",
        percent: "10.0000"
      },
      {
        name: "Employer PF",
        position: 1,
        side: "employer_contribution",
        kind: "percent",
        percent: "12.0000",
        ceiling_minor: 800_000
      },
      {
        name: "Insurance",
        position: 2,
        side: "employee_deduction",
        kind: "fixed",
        amount_minor: 50_000
      }
    ]
  end

  before { sign_up_admin! }

  describe "GET /entities/:id/pay_rules" do
    it "lists rules in position order" do
      entity = create_entity!
      post pay_rules_path(entity), params: {
        name: "B", side: "employee_deduction", kind: "percent", percent: "5.0000"
      }, as: :json
      post pay_rules_path(entity), params: {
        name: "A", side: "employee_deduction", kind: "percent", percent: "10.0000"
      }, as: :json

      get pay_rules_path(entity), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.map { |r| r["name"] }).to eq(%w[B A])
      expect(json.first).to include("side" => "employee_deduction", "kind" => "percent")
    end

    it "returns 404 for another company's entity" do
      entity = create_entity!
      other = Company.create!(
        legal_name: "Other",
        primary_currency: "USD",
        payroll_day: 31,
        next_payroll_on: Date.new(2026, 4, 30)
      )
      foreign = other.entities.create!(name: "Foreign", country: "Canada")

      get pay_rules_path(foreign), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /entities/:id/pay_rules" do
    it "creates a percent deduction rule" do
      entity = create_entity!

      expect do
        post pay_rules_path(entity), params: {
          name: "Tax",
          side: "employee_deduction",
          kind: "percent",
          percent: "10.0000",
          ceiling_minor: 800_000
        }, as: :json
      end.to change(PayRule, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include(
        "name" => "Tax",
        "side" => "employee_deduction",
        "kind" => "percent",
        "percent" => "10.0000",
        "ceiling_minor" => 800_000,
        "position" => 0
      )
    end

    it "returns 422 for invalid rule shape" do
      entity = create_entity!

      post pay_rules_path(entity), params: {
        name: "",
        side: "earning",
        kind: "percent",
        percent: "10.0000"
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["name"]).to be_present
    end
  end

  describe "PATCH /entities/:id/pay_rules/:rule_id" do
    it "updates a rule" do
      entity = create_entity!
      post pay_rules_path(entity), params: {
        name: "Tax", side: "employee_deduction", kind: "percent", percent: "10.0000"
      }, as: :json
      rule = PayRule.last

      patch pay_rule_path(entity, rule), params: { name: "Income Tax" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["name"]).to eq("Income Tax")
    end
  end

  describe "DELETE /entities/:id/pay_rules/:rule_id" do
    it "deletes a rule" do
      entity = create_entity!
      post pay_rules_path(entity), params: {
        name: "Tax", side: "employee_deduction", kind: "percent", percent: "10.0000"
      }, as: :json
      rule = PayRule.last

      expect do
        delete pay_rule_path(entity, rule), as: :json
      end.to change(PayRule, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PATCH /entities/:id/pay_rules/order" do
    it "reorders rules by rule_ids" do
      entity = create_entity!
      post pay_rules_path(entity), params: {
        name: "First", side: "employee_deduction", kind: "percent", percent: "5.0000"
      }, as: :json
      first = PayRule.last
      post pay_rules_path(entity), params: {
        name: "Second", side: "employee_deduction", kind: "percent", percent: "10.0000"
      }, as: :json
      second = PayRule.last

      patch "#{pay_rules_path(entity)}/order", params: { rule_ids: [second.id, first.id] }, as: :json

      expect(response).to have_http_status(:ok)
      get pay_rules_path(entity), as: :json
      expect(json.map { |r| r["name"] }).to eq(%w[Second First])
    end
  end

  describe "POST /entities/:id/pay_rules/preview" do
    it "returns FR-19 worked example totals in USD minor units without writing" do
      entity = create_entity!

      expect do
        post "#{pay_rules_path(entity)}/preview", params: {
          gross_minor: 1_000_000,
          rules: fr19_rules
        }, as: :json
      end.not_to change(PayRule, :count)

      expect(response).to have_http_status(:ok)
      expect(json["deductions"].map { |line| line["computed_minor"] }).to eq([100_000, 50_000])
      expect(json["employer_contributions"].map { |line| line["computed_minor"] }).to eq([96_000])
      expect(json["net_minor"]).to eq(850_000)
      expect(json["employer_cost_minor"]).to eq(1_096_000)
    end

    it "returns 422 when earning percents do not sum to 100" do
      entity = create_entity!

      post "#{pay_rules_path(entity)}/preview", params: {
        gross_minor: 1_000_000,
        rules: [
          {
            name: "Base",
            position: 0,
            side: "earning",
            kind: "percent",
            percent: "50.0000"
          }
        ]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to be_present
    end
  end
end
