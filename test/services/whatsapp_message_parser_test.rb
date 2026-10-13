# frozen_string_literal: true

require "test_helper"

class WhatsappMessageParserTest < ActiveSupport::TestCase
  setup do
    @besan_ladoo = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      is_available: true
    )

    @chakli = Product.create!(
      name: "Chakli",
      price: 500.0,
      stock_quantity: 100,
      category: "Snacks",
      is_available: true
    )
  end

  test "returns menu when message is 'menu'" do
    result = WhatsappMessageParser.new(sender_phone: "9860002903", text: "menu").call
    assert_equal "menu", result[:action]
    assert_includes result[:reply], "आजचा मेनू"
    assert_includes result[:reply], "Besan Ladoo - ₹580.00"
    assert_includes result[:reply], "Chakli - ₹500.00"
  end

  test "returns status when message is 'status' with order number" do
    today = Time.current.in_time_zone("Asia/Kolkata").to_date
    order = Order.create!(
      customer_name: "Rahul",
      customer_phone: "9860002903",
      pickup_date: today,
      pickup_time: "11:00 AM",
      payment_method: "pay_at_pickup",
      payment_status: "pending",
      status: "confirmed",
      total_amount: 580.0
    )

    result = WhatsappMessageParser.new(sender_phone: "9860002903", text: "status #{order.order_number}").call
    assert_equal "status", result[:action]
    assert_equal order.order_number, result[:order_number]
    assert_includes result[:reply], order.order_number
    assert_includes result[:reply], "स्वीकारली (Confirmed)"
  end

  test "creates order for 'order 2 besan ladoo + 1 chakli' via OrderCreator without trusting client prices" do
    result = WhatsappMessageParser.new(
      sender_phone: "9860002903",
      text: "order 2 besan ladoo + 1 chakli",
      sender_name: "Ganesh Shinde"
    ).call

    assert_equal "order_created", result[:action]
    assert_not_nil result[:order_number]

    order = result[:order]
    assert_equal "Ganesh Shinde", order.customer_name
    assert_equal "9860002903", order.customer_phone
    assert_equal 2, order.order_items.count

    # 2 * 580 + 1 * 500 = 1660.00
    assert_equal BigDecimal("1660.00"), order.total_amount
    assert_includes result[:reply], "नोंदवली गेली आहे"
    assert_includes result[:reply], order.order_number
    assert_includes result[:reply], "₹1660.00"
  end

  test "returns helpful error message when product is unknown" do
    result = WhatsappMessageParser.new(
      sender_phone: "9860002903",
      text: "order 3 nonexistent sweet"
    ).call

    assert_equal "order_failed", result[:action]
    assert_includes result[:reply], "पदार्थ सापडला नाही"
  end

  test "returns faq response for unknown greeting or query" do
    result = WhatsappMessageParser.new(
      sender_phone: "9860002903",
      text: "hello, what are your shop timings?"
    ).call

    assert_equal "faq", result[:action]
    assert_includes result[:reply], "Tawade Kitchen मध्ये आपले स्वागत आहे"
    assert_includes result[:reply], "उपलब्ध आज्ञा (Commands)"
  end
end
