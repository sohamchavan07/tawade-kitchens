# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development? && !AdminUser.exists?(email: 'admin@example.com')

products = [
  { name: 'Besan Ladoo', price: 500, category: 'Sweets', stock_quantity: 50, description: 'Homemade besan ladoo with pure ghee.' },
  { name: 'Rava Ladoo', price: 450, category: 'Sweets', stock_quantity: 40, description: 'Soft and delicious rava ladoos.' },
  { name: 'Bundi Ladoo', price: 480, category: 'Sweets', stock_quantity: 30, description: 'Traditional bundi ladoos.' },
  { name: 'Chakli', price: 400, category: 'Snacks', stock_quantity: 100, description: 'Crispy and spicy chakli.' },
  { name: 'Shankarpali', price: 350, category: 'Snacks', stock_quantity: 80, description: 'Sweet and crunchy shankarpali.' },
  { name: 'Chivda', price: 300, category: 'Snacks', stock_quantity: 60, description: 'Poha chivda with nuts.' },
  { name: 'Anarsa', price: 550, category: 'Sweets', stock_quantity: 25, description: 'Traditional rice-based sweet.' },
  { name: 'Bakarvadi', price: 420, category: 'Snacks', stock_quantity: 45, description: 'Spicy and tangy bakarvadi.' },
  { name: 'Sev', price: 280, category: 'Snacks', stock_quantity: 70, description: 'Fine gram flour sev.' }
]

products.each do |p|
  Product.find_or_create_by!(name: p[:name]) do |product|
    product.price = p[:price]
    product.category = p[:category]
    product.stock_quantity = p[:stock_quantity]
    product.description = p[:description]
  end
end
