# frozen_string_literal: true

module AuthHelpers
  def sign_in_via_api(email:, password:)
    post "/session", params: { email:, password: }, as: :json
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
