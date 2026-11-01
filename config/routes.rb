Rails.application.routes.draw do
  post "/sign_up", to: "sign_ups#create"
  resource :session, only: %i[show create destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end
