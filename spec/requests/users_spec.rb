# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users API", type: :request do
  def json
    response.parsed_body
  end

  before { sign_up_admin! }

  describe "GET /users" do
    it "lists users in the company" do
      entity = create_entity!
      create_hr_user!(admin_company: Company.last, entity:, email: "hr@example.com")

      get "/users", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.size).to eq(2)
      admin_row = json.find { |u| u["access_role"] == "admin" }
      hr_row = json.find { |u| u["access_role"] == "hr" }
      expect(admin_row["email"]).to eq("jane@example.com")
      expect(hr_row["email"]).to eq("hr@example.com")
      expect(hr_row["entity_id"]).to eq(entity.id)
    end
  end

  describe "POST /users" do
    it "creates an admin user" do
      expect do
        post "/users", params: {
          name: "Bob Admin",
          email: "bob@example.com",
          password: "password123",
          access_role: "admin"
        }, as: :json
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["access_role"]).to eq("admin")
      expect(json["entity_id"]).to be_nil
    end

    it "creates an HR user tied to an entity in the company" do
      entity = create_entity!

      post "/users", params: {
        name: "Pat HR",
        email: "hr@example.com",
        password: "password123",
        access_role: "hr",
        entity_id: entity.id
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["entity_id"]).to eq(entity.id)
      expect(json["access_role"]).to eq("hr")
    end

    it "returns 422 when HR user has no entity_id" do
      post "/users", params: {
        name: "Bad HR",
        email: "bad@example.com",
        password: "password123",
        access_role: "hr"
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["entity_id"]).to be_present
    end

    it "returns 422 for duplicate email" do
      post "/users", params: {
        name: "Dup",
        email: "jane@example.com",
        password: "password123",
        access_role: "admin"
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["email"]).to be_present
    end
  end
end
