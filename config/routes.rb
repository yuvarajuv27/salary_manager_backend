Rails.application.routes.draw do
  post "/sign_up", to: "sign_ups#create"
  resource :session, only: %i[show create destroy]

  resource :company, only: %i[show update]
  resources :users, only: %i[index create]
  resources :entities, only: %i[index show create update destroy] do
    resources :pay_rules, only: %i[index create update destroy], param: :rule_id do
      collection do
        patch :order
        post :preview
      end
    end
    resources :employees, only: %i[index show create update destroy] do
      member do
        put "salary", to: "salaries#correct"
        put "salary_revision", to: "salaries#revise"
      end
      resources :leave_days, only: %i[index create]
      delete "leave_days/:date", to: "leave_days#destroy"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
