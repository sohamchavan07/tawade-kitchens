require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Test Chakli", price: 400.0, stock_quantity: 50, is_available: true)
    @today = Time.current.in_time_zone("Asia/Kolkata").to_date
    @order = Order.create!(
      customer_name: "Test Customer",
      customer_phone: "9876543210",
      pickup_date: @today,
      pickup_time: "10:00 AM",
      total_amount: 800.0
    )
  end

  test "automatically sets item_name, unit_price, and subtotal" do
    item = OrderItem.new(order: @order, product: @product, quantity: 2)
    assert item.valid?, item.errors.full_messages.to_sentence
    assert_equal "Test Chakli", item.item_name
    assert_equal 400.0, item.unit_price
    assert_equal 800.0, item.subtotal
  end

  test "rejects negative quantity" do
    item = OrderItem.new(order: @order, product: @product, quantity: -1)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end
end
