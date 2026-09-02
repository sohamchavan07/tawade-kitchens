# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = if Rails.env.production?
      ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)
    else
      env_origins = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)
      env_origins.presence || [
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:3000"
      ]
    end

    origins(*origins_list)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
