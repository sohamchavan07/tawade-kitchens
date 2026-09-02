require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "valid product creation" do
    product = Product.new(
      name: "Special Besan Ladoo",
      price: 580.0,
      stock_quantity: 20,
      category: "Sweets",
      is_available: true,
      preparation_time: 15,
      vegetarian: true
    )
    assert product.valid?
  end

  test "requires name and price" do
    product = Product.new(name: nil, price: nil)
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
    assert_includes product.errors[:price], "can't be blank"
  end

  test "price must be non-negative" do
    product = Product.new(name: "Test", price: -10, stock_quantity: 5)
    assert_not product.valid?
    assert_includes product.errors[:price], "must be greater than or equal to 0"
  end

  test "available scope returns only available products" do
    p1 = Product.create!(name: "Avail 1", price: 100, stock_quantity: 10, is_available: true)
    p2 = Product.create!(name: "Unavail 1", price: 100, stock_quantity: 10, is_available: false)

    available_products = Product.available
    assert_includes available_products, p1
    assert_not_includes available_products, p2
  end
end
