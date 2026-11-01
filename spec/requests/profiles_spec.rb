# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile API", type: :request do
  def json
    response.parsed_body
  end

  it "shows and updates the signed-in user profile" do
    sign_up_admin!

    get "/profile", as: :json
    expect(response).to have_http_status(:ok)
    expect(json["email"]).to eq("jane@example.com")

    patch "/profile",
          params: { name: "Jane Updated", email: "jane.updated@example.com", password: "newpassword1" },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(json["name"]).to eq("Jane Updated")
    expect(json["email"]).to eq("jane.updated@example.com")

    post "/session", params: { email: "jane.updated@example.com", password: "newpassword1" }, as: :json
    expect(response).to have_http_status(:ok)
  end

  it "rejects a taken email" do
    sign_up_admin!(email: "one@example.com")
    sign_up_admin!(
      email: "two@example.com",
      legal_name: "Other Co",
      name: "Other Admin"
    )

    patch "/profile", params: { email: "one@example.com" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end
end
