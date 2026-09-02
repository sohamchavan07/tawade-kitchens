# frozen_string_literal: true

AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development? && !AdminUser.exists?(email: 'admin@example.com')

products = [
  { name: 'Besan Ladoo', price: 580, category: 'Sweets', stock_quantity: 50, description: 'Homemade besan ladoo with pure ghee and dry fruits.', preparation_time: 15, vegetarian: true, is_available: true },
  { name: 'Rava Ladoo', price: 560, category: 'Sweets', stock_quantity: 40, description: 'Soft and delicious rava ladoos made traditionally.', preparation_time: 15, vegetarian: true, is_available: true },
  { name: 'Bundi Ladoo', price: 400, category: 'Sweets', stock_quantity: 30, description: 'Traditional aromatic bundi ladoos.', preparation_time: 15, vegetarian: true, is_available: true },
  { name: 'Chakli', price: 500, category: 'Snacks', stock_quantity: 100, description: 'Crispy, crunchy and authentic spiced chakli.', preparation_time: 10, vegetarian: true, is_available: true },
  { name: 'Shankarpali', price: 380, category: 'Snacks', stock_quantity: 80, description: 'Sweet and flaky homemade shankarpali.', preparation_time: 10, vegetarian: true, is_available: true },
  { name: 'Chivda', price: 400, category: 'Snacks', stock_quantity: 60, description: 'Special Kolhapuri poha chivda with peanuts and roasted spices.', preparation_time: 10, vegetarian: true, is_available: true },
  { name: 'Anarsa', price: 750, category: 'Sweets', stock_quantity: 25, description: 'Traditional festive rice-and-jaggery sweet with poppy seeds.', preparation_time: 20, vegetarian: true, is_available: true },
  { name: 'Bakarvadi', price: 450, category: 'Snacks', stock_quantity: 45, description: 'Spicy, tangy, and crunchy roll snack.', preparation_time: 10, vegetarian: true, is_available: true },
  { name: 'Sev', price: 350, category: 'Snacks', stock_quantity: 70, description: 'Crisp and savoury fine gram flour sev.', preparation_time: 10, vegetarian: true, is_available: true }
]

products.each do |p|
  product = Product.find_or_initialize_by(name: p[:name])
  product.price = p[:price]
  product.category = p[:category]
  product.stock_quantity = p[:stock_quantity]
  product.description = p[:description]
  product.preparation_time = p[:preparation_time]
  product.vegetarian = p[:vegetarian]
  product.is_available = p[:is_available]
  product.save!
end
