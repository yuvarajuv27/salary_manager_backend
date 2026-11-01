# frozen_string_literal: true

module OrganizationHelpers
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

  def sign_up_admin!(overrides = {})
    post "/sign_up", params: sign_up_params(overrides), as: :json
    expect(response).to have_http_status(:created)
    User.find_by!(email: overrides.fetch(:email, "jane@example.com"))
  end

  def create_entity!(name: "US Entity", country: "United States")
    post "/entities", params: { name:, country: }, as: :json
    expect(response).to have_http_status(:created)
    Entity.order(:id).last
  end

  def create_hr_user!(admin_company:, entity:, email: "hr@example.com", name: "Pat HR", password: "password123")
    post "/users", params: {
      name:,
      email:,
      password:,
      access_role: "hr",
      entity_id: entity.id
    }, as: :json
    expect(response).to have_http_status(:created)
    User.find_by!(email:)
  end
end

RSpec.configure do |config|
  config.include OrganizationHelpers, type: :request
end
