# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authorization", type: :request do
  def json
    response.parsed_body
  end

  it "returns 404 when HR requests another entity" do
    admin = sign_up_admin!
    entity_a = create_entity!(name: "Entity A")
    entity_b = create_entity!(name: "Entity B", country: "Canada")
    create_hr_user!(admin_company: admin.company, entity: entity_a, email: "hr@example.com")

    delete "/session", as: :json
    sign_in_via_api(email: "hr@example.com", password: "password123")

    get "/entities/#{entity_b.id}", as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when HR accesses admin-only company settings" do
    admin = sign_up_admin!
    entity = create_entity!
    create_hr_user!(admin_company: admin.company, entity:, email: "hr@example.com")

    delete "/session", as: :json
    sign_in_via_api(email: "hr@example.com", password: "password123")

    get "/company", as: :json
    expect(response).to have_http_status(:not_found)

    patch "/company", params: { legal_name: "Hacked" }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when HR lists or creates users" do
    admin = sign_up_admin!
    entity = create_entity!
    create_hr_user!(admin_company: admin.company, entity:, email: "hr@example.com")

    delete "/session", as: :json
    sign_in_via_api(email: "hr@example.com", password: "password123")

    get "/users", as: :json
    expect(response).to have_http_status(:not_found)

    post "/users", params: {
      name: "New HR",
      email: "new@example.com",
      password: "password123",
      access_role: "hr",
      entity_id: entity.id
    }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when HR posts a new entity" do
    admin = sign_up_admin!
    entity = create_entity!
    create_hr_user!(admin_company: admin.company, entity:, email: "hr@example.com")

    delete "/session", as: :json
    sign_in_via_api(email: "hr@example.com", password: "password123")

    post "/entities", params: { name: "Sneaky", country: "France" }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for another company's entity when signed in as admin" do
    sign_up_admin!(email: "one@example.com")
    entity_one = create_entity!

    sign_up_admin!(email: "two@example.com", legal_name: "Beta LLC")
    entity_two = create_entity!(name: "Beta Entity", country: "United Kingdom")

    delete "/session", as: :json
    sign_in_via_api(email: "one@example.com", password: "password123")

    get "/entities/#{entity_two.id}", as: :json
    expect(response).to have_http_status(:not_found)

    expect(entity_one.company_id).not_to eq(entity_two.company_id)
  end
end
