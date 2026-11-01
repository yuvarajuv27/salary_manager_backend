# frozen_string_literal: true

module WorkforceHelpers
  def us_bank_details(overrides = {})
    {
      account_holder_name: "Jane Doe",
      account_number: "1234567890",
      routing_number: "021000021"
    }.merge(overrides)
  end

  def india_bank_details(overrides = {})
    {
      account_holder_name: "Raj Kumar",
      account_number: "1234567890",
      ifsc: "HDFC0001234"
    }.merge(overrides)
  end

  def create_employee!(entity:, **attrs)
    body = {
      name: "Alex",
      job_role: "Analyst",
      department: "Finance",
      start_on: "2026-01-01",
      bank_details: us_bank_details
    }.merge(attrs)
    post "/entities/#{entity.id}/employees", params: body, as: :json
    expect(response).to have_http_status(:created)
    Employee.order(:id).last
  end
end

RSpec.configure do |config|
  config.include WorkforceHelpers, type: :request
end
