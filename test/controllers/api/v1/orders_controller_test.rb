# frozen_string_literal: true

require "test_helper"

class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @today = Time.current.in_time_zone("Asia/Kolkata").to_date

    @product = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      is_available: true
    )
  end

  test "POST /api/v1/orders creates order and returns 201 Created with safe summary" do
    post "/api/v1/orders", params: {
      order: {
        customer_name: "Ramesh Patil",
        customer_phone: "9860002903",
        pickup_date: @today + 1.day,
        pickup_time: "11:00 AM",
        payment_method: "pay_at_pickup",
        notes: "Gift packaging please",
        items: [
          { product_id: @product.id, quantity: 2 }
        ]
      }
    }, as: :json

    assert_response :created

    json = JSON.parse(response.body)
    assert_not_nil json["order_number"]
    assert_match(/\ATK-\d{8}-[A-Z0-9]{4}\z/, json["order_number"])
    assert_equal "pending", json["status"]
    assert_equal "pay_at_pickup", json["payment_method"]
    assert_equal "pending", json["payment_status"]
    assert_equal 1160.0, json["total_amount"]
    assert_equal "Ramesh Patil", json["customer_name"]
    assert_equal 1, json["items"].length
    assert_equal "Besan Ladoo", json["items"][0]["name"]
    assert_equal 2, json["items"][0]["quantity"]
    assert_equal 580.0, json["items"][0]["unit_price"]
    assert_equal 1160.0, json["items"][0]["subtotal"]
    assert_not_nil json["pickup_address"]
  end

  test "POST /api/v1/orders with upi_after_confirmation creates order with pending payment status" do
    post "/api/v1/orders", params: {
      order: {
        customer_name: "Ramesh Patil",
        customer_phone: "9860002903",
        pickup_date: @today,
        pickup_time: "12:00 PM",
        payment_method: "upi_after_confirmation",
        items: [
          { product_id: @product.id, quantity: 1 }
        ]
      }
    }, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "pending", json["payment_status"]
    assert_equal "upi_after_confirmation", json["payment_method"]
  end

  test "POST /api/v1/orders rejects legacy 'upi' payment method" do
    post "/api/v1/orders", params: {
      order: {
        customer_name: "Ramesh Patil",
        customer_phone: "9860002903",
        pickup_date: @today,
        pickup_time: "12:00 PM",
        payment_method: "upi",
        payment_reference: "UTR492817294829",
        items: [
          { product_id: @product.id, quantity: 1 }
        ]
      }
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["details"].to_sentence, "Invalid payment method"
  end

  test "POST /api/v1/orders returns 422 Unprocessable Entity on validation failure" do
    post "/api/v1/orders", params: {
      order: {
        customer_name: "",
        customer_phone: "invalid",
        pickup_date: @today - 2.days,
        pickup_time: "08:00 AM",
        payment_method: "upi",
        payment_reference: "",
        items: []
      }
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Order creation failed", json["error"]
    assert json["details"].is_a?(Array)
    assert json["details"].length > 0
  end

  test "GET /api/v1/orders/:order_number returns public order details" do
    create_result = OrderCreator.new(
      customer_name: "Pooja Kulkarni",
      customer_phone: "9876543210",
      pickup_date: @today + 2.days,
      pickup_time: "04:30 PM",
      payment_method: "pay_at_pickup",
      items: [ { product_id: @product.id, quantity: 1 } ]
    ).call
    assert create_result[:success]
    order = create_result[:order]

    get "/api/v1/orders/#{order.order_number}"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal order.order_number, json["order_number"]
    assert_equal "pending", json["status"]
    assert_equal "pending", json["payment_status"]
    assert_equal 580.0, json["total_amount"]
    assert_equal "Pooja Kulkarni", json["customer_name"]
    assert_equal 1, json["items"].length
  end

  test "GET /api/v1/orders/:order_number returns 404 Not Found for non-existent order" do
    get "/api/v1/orders/TK-99999999-XXXX"
    assert_response :not_found

    json = JSON.parse(response.body)
    assert_equal "Order not found", json["error"]
  end
end
