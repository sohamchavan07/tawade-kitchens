# frozen_string_literal: true

require "test_helper"

class AdminOrdersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.find_or_create_by!(email: "admin_test@tawadekitchen.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end

    @today = Time.current.in_time_zone("Asia/Kolkata").to_date

    @product = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      is_available: true
    )

    @order = Order.create!(
      customer_name: "Ramesh Patil",
      customer_phone: "9860002903",
      pickup_date: @today + 1.day,
      pickup_time: "10:30 AM",
      payment_method: "pay_at_pickup",
      payment_status: "pending",
      status: "pending",
      total_amount: 580.0
    )

    @upi_order = Order.create!(
      customer_name: "Suresh Kulkarni",
      customer_phone: "9876543210",
      pickup_date: @today + 1.day,
      pickup_time: "11:30 AM",
      payment_method: "upi_after_confirmation",
      payment_status: "pending",
      status: "pending",
      total_amount: 580.0
    )
  end

  test "unauthenticated access to admin orders redirects to admin login" do
    get "/admin/orders"
    assert_response :redirect
    assert_redirected_to new_admin_user_session_path
  end

  test "authenticated admin can view orders index and show page" do
    sign_in @admin

    get "/admin/orders"
    assert_response :success
    assert_includes response.body, @order.order_number
    assert_includes response.body, "Ramesh Patil"
    assert_includes response.body, "9860002903"

    get "/admin/orders/#{@order.id}"
    assert_response :success
    assert_includes response.body, @order.order_number
  end

  test "authenticated admin can confirm order and verify payment" do
    sign_in @admin

    # Confirm order member action
    put "/admin/orders/#{@order.id}/confirm_order"
    assert_response :redirect
    assert_equal "confirmed", @order.reload.status

    # Verify payment member action
    put "/admin/orders/#{@order.id}/verify_payment"
    assert_response :redirect
    assert_equal "verified", @order.reload.payment_status
  end

  test "authenticated admin can confirm UPI order, record UTR, and verify payment" do
    sign_in @admin

    # Attempt to record UTR while still pending confirmation should fail
    put "/admin/orders/#{@upi_order.id}/record_utr", params: { payment_reference: "UTR492817294829" }
    assert_response :redirect
    assert_equal "pending", @upi_order.reload.payment_status

    # Confirm order first
    put "/admin/orders/#{@upi_order.id}/confirm_order"
    assert_response :redirect
    assert_equal "confirmed", @upi_order.reload.status

    # Show page displays WhatsApp payment instructions link
    get "/admin/orders/#{@upi_order.id}"
    assert_response :success
    assert_includes response.body, "Send WhatsApp Payment Instructions"

    # Now record UTR
    put "/admin/orders/#{@upi_order.id}/record_utr", params: { payment_reference: "UTR492817294829" }
    assert_response :redirect
    @upi_order.reload
    assert_equal "submitted", @upi_order.payment_status
    assert_equal "UTR492817294829", @upi_order.payment_reference

    # Finally verify payment manually
    put "/admin/orders/#{@upi_order.id}/verify_payment"
    assert_response :redirect
    assert_equal "verified", @upi_order.reload.payment_status
  end
end
