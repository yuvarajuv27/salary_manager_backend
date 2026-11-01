# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /sign_up", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def sign_up_params(overrides = {})
    {
      legal_name: "Acme Corp",
      primary_currency: "USD",
      payroll_day: 31,
      name: "Jane Admin",
      email: "jane@example.com",
      password: "password123"
    }.merge(overrides)
  end

  def json
    response.parsed_body
  end

  it "creates a company and its first admin user" do
    expect do
      post "/sign_up", params: sign_up_params, as: :json
    end.to change(Company, :count).by(1).and change(User, :count).by(1)

    expect(response).to have_http_status(:created)
    user = User.find_by!(email: "jane@example.com")
    expect(user.access_role).to eq("admin")
    expect(user.entity_id).to be_nil
    expect(user.company.legal_name).to eq("Acme Corp")
    expect(json["user"]["id"]).to eq(user.id)
    expect(json["user"]["access_role"]).to eq("admin")
    expect(json["company"]["id"]).to eq(user.company_id)
    expect(response.headers["Set-Cookie"]).to include("_salary_manager_session")
  end

  it "sets next_payroll_on to the next future payroll date" do
    travel_to Time.utc(2026, 3, 31, 12, 0, 0) do
      post "/sign_up", params: sign_up_params, as: :json

      expect(response).to have_http_status(:created)
      expect(json["company"]["next_payroll_on"]).to eq("2026-04-30")
    end
  end

  it "signs the user in via session cookie" do
    post "/sign_up", params: sign_up_params, as: :json
    expect(response).to have_http_status(:created)

    get "/session", as: :json
    expect(response).to have_http_status(:ok)
    expect(json["user"]["email"]).to eq("jane@example.com")
    expect(json["company"]["has_entity"]).to be(false)
  end

  it "returns 422 when the email is already taken" do
    post "/sign_up", params: sign_up_params, as: :json
    expect(response).to have_http_status(:created)

    expect do
      post "/sign_up", params: sign_up_params.merge(legal_name: "Other Co", email: "jane@example.com"), as: :json
    end.not_to change(Company, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to be_present
    expect(json["errors"]["email"]).to be_present
  end

  it "creates two isolated companies for two sign-ups" do
    post "/sign_up", params: sign_up_params(email: "one@example.com"), as: :json
    expect(response).to have_http_status(:created)
    company_one_id = json["company"]["id"]

    post "/sign_up", params: sign_up_params(email: "two@example.com", legal_name: "Beta LLC"), as: :json
    expect(response).to have_http_status(:created)
    company_two_id = json["company"]["id"]

    expect(company_one_id).not_to eq(company_two_id)
    expect(Company.count).to eq(2)
  end
end
