Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*" # In production, replace with your frontend URL
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
