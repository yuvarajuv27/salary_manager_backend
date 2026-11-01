Rails.application.routes.draw do
  post "/sign_up", to: "sign_ups#create"
  resource :session, only: %i[show create destroy]

  resource :company, only: %i[show update]
  resources :users, only: %i[index create]
  resources :entities, only: %i[index show create update destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end
