# frozen_string_literal: true

require "test_helper"

class OrderCreatorTest < ActiveSupport::TestCase
  setup do
    @today = Time.current.in_time_zone("Asia/Kolkata").to_date

    @besan_ladoo = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      is_available: true
    )

    @chakli = Product.create!(
      name: "Chakli",
      price: 400.0,
      stock_quantity: 100,
      category: "Snacks",
      is_available: true
    )

    @unavailable_product = Product.create!(
      name: "Unavailable Sweet",
      price: 600.0,
      stock_quantity: 0,
      category: "Sweets",
      is_available: false
    )
  end

  test "creates valid pay_at_pickup order and calculates total server-side" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "+91 98600 02903",
      pickup_date: @today + 1.day,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      notes: "Please pack in two boxes",
      items: [
        { product_id: @besan_ladoo.id, quantity: 2 },
        { product_id: @chakli.id, quantity: 1 }
      ]
    }

    result = OrderCreator.new(params).call
    assert result[:success], result[:errors]&.join(", ")

    order = result[:order]
    assert_not_nil order
    assert_equal "Ramesh Patil", order.customer_name
    assert_equal "9860002903", order.customer_phone
    assert_equal "pending", order.status
    assert_equal "pending", order.payment_status
    assert_equal "pay_at_pickup", order.payment_method
    assert_equal 2, order.order_items.count

    # 2 * 580.0 + 1 * 400.0 = 1560.00
    assert_equal BigDecimal("1560.00"), order.total_amount
    assert_match(/\ATK-\d{8}-[A-Z0-9]{4}\z/, order.order_number)
  end

  test "creates valid upi_after_confirmation order with pending status without requiring a UTR at checkout" do
    params = {
      customer_name: "Anita Deshmukh",
      customer_phone: "9876543210",
      pickup_date: @today,
      pickup_time: "02:00 PM",
      payment_method: "upi_after_confirmation",
      items: [
        { product_id: @besan_ladoo.id, quantity: 1 }
      ]
    }

    result = OrderCreator.new(params).call
    assert result[:success], result[:errors]&.join(", ")

    order = result[:order]
    assert_equal "pending", order.payment_status
    assert_nil order.payment_reference
    assert_equal "upi_after_confirmation", order.payment_method
  end

  test "rejects legacy 'upi' payment method for new order creation" do
    params = {
      customer_name: "Anita Deshmukh",
      customer_phone: "9876543210",
      pickup_date: @today,
      pickup_time: "02:00 PM",
      payment_method: "upi",
      payment_reference: "UTR12345678",
      items: [
        { product_id: @besan_ladoo.id, quantity: 1 }
      ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "Invalid payment method. Allowed methods: pay_at_pickup, upi_after_confirmation"
  end

  test "rejects empty items list" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: []
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "Order must contain at least one item"
  end

  test "rejects missing product ID" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [
        { product_id: 9999999, quantity: 1 }
      ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "product IDs do not exist"
  end

  test "rejects unavailable product" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [
        { product_id: @unavailable_product.id, quantity: 1 }
      ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "out of stock / unavailable"
  end

  test "rejects zero, negative, decimal, and excessive quantities" do
    # Zero quantity
    res_zero = OrderCreator.new(
      customer_name: "Test",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: 0 } ]
    ).call
    assert_not res_zero[:success]
    assert_includes res_zero[:errors].to_sentence, "positive integer"

    # Negative quantity
    res_neg = OrderCreator.new(
      customer_name: "Test",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: -2 } ]
    ).call
    assert_not res_neg[:success]
    assert_includes res_neg[:errors].to_sentence, "positive integer"

    # Excessive quantity > 50
    res_excess = OrderCreator.new(
      customer_name: "Test",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: 51 } ]
    ).call
    assert_not res_excess[:success]
    assert_includes res_excess[:errors].to_sentence, "cannot exceed 50 units"
  end

  test "ignores client-tampered prices and uses database prices" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      total_amount: 10.0, # Client attempts to set total to ₹10
      items: [
        { product_id: @besan_ladoo.id, quantity: 1, unit_price: 1.0, subtotal: 1.0, name: "Free Ladoo" }
      ]
    }

    result = OrderCreator.new(params).call
    assert result[:success]

    order = result[:order]
    # Price must be 580.00 from DB, not 1.00
    assert_equal BigDecimal("580.00"), order.total_amount
    assert_equal BigDecimal("580.00"), order.order_items.first.unit_price
    assert_equal BigDecimal("580.00"), order.order_items.first.subtotal
    assert_equal "Besan Ladoo", order.order_items.first.item_name
  end

  test "rejects past pickup date" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today - 1.day,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: 1 } ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "cannot be in the past"
  end

  test "rejects pickup time outside operating hours" do
    # 08:00 AM is before 09:00 AM opening
    params_early = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "08:00 AM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: 1 } ]
    }
    res_early = OrderCreator.new(params_early).call
    assert_not res_early[:success]
    assert_includes res_early[:errors].to_sentence, "operating hours"

    # 09:30 PM is after 08:00 PM closing
    params_late = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "09:30 PM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @besan_ladoo.id, quantity: 1 } ]
    }
    res_late = OrderCreator.new(params_late).call
    assert_not res_late[:success]
    assert_includes res_late[:errors].to_sentence, "operating hours"
  end

  test "rejects invalid payment method" do
    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "crypto_currency",
      items: [ { product_id: @besan_ladoo.id, quantity: 1 } ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_includes result[:errors].to_sentence, "Invalid payment method"
  end

  test "transaction rollback occurs if one item fails" do
    initial_order_count = Order.count
    initial_item_count = OrderItem.count

    params = {
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      items: [
        { product_id: @besan_ladoo.id, quantity: 1 },
        { product_id: @unavailable_product.id, quantity: 1 } # Fails
      ]
    }

    result = OrderCreator.new(params).call
    assert_not result[:success]
    assert_equal initial_order_count, Order.count
    assert_equal initial_item_count, OrderItem.count
  end
end
