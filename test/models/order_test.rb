require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @today = Time.current.in_time_zone("Asia/Kolkata").to_date
  end

  test "valid order creation auto-generates order_number and sets defaults" do
    order = Order.new(
      customer_name: "Ramesh Patil",
      customer_phone: "9876543210",
      pickup_date: @today + 1.day,
      pickup_time: "11:30 AM",
      payment_method: "pay_at_pickup",
      total_amount: 580.0
    )
    assert order.valid?, order.errors.full_messages.to_sentence
    assert order.save
    assert_match(/\ATK-\d{8}-[A-Z0-9]{4}\z/, order.order_number)
    assert_equal "pending", order.status
    assert_equal "pending", order.payment_status
  end

  test "rejects past pickup date on create" do
    order = Order.new(
      customer_name: "Ramesh Patil",
      customer_phone: "9876543210",
      pickup_date: @today - 1.day,
      pickup_time: "11:30 AM",
      total_amount: 100.0
    )
    assert_not order.valid?
    assert_includes order.errors[:pickup_date], "cannot be in the past"
  end

  test "allows today pickup date" do
    order = Order.new(
      customer_name: "Ramesh Patil",
      customer_phone: "9876543210",
      pickup_date: @today,
      pickup_time: "05:00 PM",
      total_amount: 100.0
    )
    assert order.valid?, order.errors.full_messages.to_sentence
  end

  test "rejects invalid status" do
    order = Order.new(
      total_amount: 100.0,
      status: "out_for_delivery", # Must not allow delivery statuses
      pickup_date: @today
    )
    assert_not order.valid?
    assert_includes order.errors[:status], "is not included in the list"
  end

  test "rejects invalid payment status" do
    order = Order.new(
      total_amount: 100.0,
      payment_status: "unknown_status",
      pickup_date: @today
    )
    assert_not order.valid?
    assert_includes order.errors[:payment_status], "is not included in the list"
  end
end
