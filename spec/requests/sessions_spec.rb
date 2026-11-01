# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session API", type: :request do
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

  before do
    post "/sign_up", params: sign_up_params, as: :json
    expect(response).to have_http_status(:created)
  end

  describe "POST /session" do
    it "returns 200 and sets the session cookie with valid credentials" do
      delete "/session", as: :json
      expect(response).to have_http_status(:no_content)

      post "/session", params: { email: "jane@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers["Set-Cookie"]).to include("_salary_manager_session")
      expect(json["user"]["email"]).to eq("jane@example.com")
      expect(json["company"]["has_entity"]).to be(false)
    end

    it "returns 401 for a wrong password" do
      delete "/session", as: :json

      post "/session", params: { email: "jane@example.com", password: "wrong-password" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for an unknown email" do
      delete "/session", as: :json

      post "/session", params: { email: "nobody@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /session" do
    it "returns the current user and company" do
      user = User.find_by!(email: "jane@example.com")

      get "/session", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "user" => {
          "id" => user.id,
          "name" => "Jane Admin",
          "email" => "jane@example.com",
          "access_role" => "admin",
          "entity_id" => nil
        },
        "company" => {
          "id" => user.company_id,
          "has_entity" => false
        }
      )
    end

    it "returns 401 when not signed in" do
      delete "/session", as: :json
      expect(response).to have_http_status(:no_content)

      get "/session", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /session" do
    it "clears the session" do
      delete "/session", as: :json
      expect(response).to have_http_status(:no_content)

      get "/session", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "sign_in_via_api helper" do
    it "signs in through POST /session" do
      delete "/session", as: :json

      sign_in_via_api(email: "jane@example.com", password: "password123")
      expect(response).to have_http_status(:ok)

      get "/session", as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
