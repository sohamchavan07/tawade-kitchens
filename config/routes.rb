Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users, skip: [ :registrations, :sessions ], controllers: { omniauth_callbacks: "users/omniauth_callbacks" }, only: [ :omniauth, :omniauth_callbacks ]
  devise_scope :user do
    # SPA should handle these GET requests
    get "/users/sign_in", to: "application#fallback_index_html", as: :new_user_session
    get "/users/sign_up", to: "application#fallback_index_html", as: :new_user_registration

    # Keep the POST/DELETE routes for Devise controllers
    post "/users/sign_in", to: "devise/sessions#create", as: :user_session
    delete "/users/sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
    post "/users", to: "devise/registrations#create", as: :user_registration
  end
  namespace :api do
    namespace :v1 do
      get "auth/status", to: "auth#status"
      resources :products, only: [ :index, :show ]
      resources :orders, only: [ :create, :show ], param: :order_number
      get "whatsapp/webhook", to: "whatsapp#verify"
      post "whatsapp/webhook", to: "whatsapp#webhook"
      post "assistant/chat", to: "assistant#chat"
    end
    resources :products, only: [ :index, :show ]
    resources :orders, only: [ :create ]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "ping", to: "health#ping"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "application#fallback_index_html"
  get "*path", to: "application#fallback_index_html", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
