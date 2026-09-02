# frozen_string_literal: true

require "test_helper"

class OrderTransitionsTest < ActiveSupport::TestCase
  setup do
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

    @order_item = @order.order_items.create!(
      product: @product,
      item_name: "Besan Ladoo",
      unit_price: 580.0,
      quantity: 1,
      subtotal: 580.0
    )
  end

  test "valid order status workflow succeeds" do
    # pending -> confirmed
    assert @order.can_transition_to_status?("confirmed")
    @order.transition_to_status!("confirmed")
    assert_equal "confirmed", @order.status

    # confirmed -> preparing
    assert @order.can_transition_to_status?("preparing")
    @order.transition_to_status!("preparing")
    assert_equal "preparing", @order.status

    # preparing -> ready_for_pickup
    assert @order.can_transition_to_status?("ready_for_pickup")
    @order.transition_to_status!("ready_for_pickup")
    assert_equal "ready_for_pickup", @order.status

    # ready_for_pickup -> collected
    assert @order.can_transition_to_status?("collected")
    @order.transition_to_status!("collected")
    assert_equal "collected", @order.status
  end

  test "invalid order status transitions are rejected" do
    # Cannot jump directly from pending to collected
    assert_not @order.can_transition_to_status?("collected")
    assert_raises(Order::InvalidStatusTransitionError) do
      @order.transition_to_status!("collected")
    end

    # Cannot transition from collected to anything else
    @order.update_columns(status: "collected")
    assert_not @order.can_transition_to_status?("pending")
    assert_not @order.can_transition_to_status?("confirmed")
  end

  test "cancellation is allowed from active states" do
    assert @order.can_transition_to_status?("cancelled")
    @order.transition_to_status!("cancelled")
    assert_equal "cancelled", @order.status

    # Once cancelled, terminal state
    assert_not @order.can_transition_to_status?("confirmed")
  end

  test "payment status transitions succeed for manual admin verification" do
    # pending -> verified
    assert @order.can_transition_to_payment_status?("verified")
    @order.transition_to_payment_status!("verified")
    assert_equal "verified", @order.payment_status

    # verified -> refunded
    assert @order.can_transition_to_payment_status?("refunded")
    @order.transition_to_payment_status!("refunded")
    assert_equal "refunded", @order.payment_status
  end

  test "UPI payment submitted transitions to verified or failed" do
    upi_order = Order.create!(
      customer_name: "Anita Deshmukh",
      customer_phone: "9876543210",
      pickup_date: @today,
      pickup_time: "02:00 PM",
      payment_method: "upi_after_confirmation",
      payment_status: "pending",
      status: "pending",
      total_amount: 580.0
    )

    # Cannot record UTR before order is confirmed
    assert_raises(Order::InvalidStatusTransitionError) do
      upi_order.record_payment_reference!("UTR987654321012")
    end

    # Confirm order first
    upi_order.transition_to_status!("confirmed")

    # Blank UTR is rejected
    assert_raises(ArgumentError) do
      upi_order.record_payment_reference!("")
    end

    # Valid UTR sets payment_status to submitted, NOT verified
    upi_order.record_payment_reference!("UTR987654321012")
    assert_equal "submitted", upi_order.payment_status
    assert_equal "UTR987654321012", upi_order.payment_reference

    # Then staff can verify or mark failed
    assert upi_order.can_transition_to_payment_status?("verified")
    assert upi_order.can_transition_to_payment_status?("failed")

    upi_order.transition_to_payment_status!("verified")
    assert_equal "verified", upi_order.payment_status
  end

  test "existing legacy upi orders continue to load and display" do
    legacy_order = Order.create!(
      customer_name: "Legacy Customer",
      customer_phone: "9860002903",
      pickup_date: @today + 1.day,
      pickup_time: "11:00 AM",
      payment_method: "upi",
      payment_status: "submitted",
      payment_reference: "LEGACY-UTR-999",
      status: "confirmed",
      total_amount: 580.0
    )

    assert_equal "upi", legacy_order.payment_method
    assert_equal "submitted", legacy_order.payment_status
    assert Order.where(payment_method: "upi").exists?(id: legacy_order.id)
  end

  test "product deletion is restricted when referenced by order items" do
    assert_not @product.destroy
    assert_includes @product.errors.full_messages.to_sentence, "Cannot delete record because dependent order items exist"
    assert Product.exists?(@product.id)
  end

  test "historical order item snapshots remain unchanged when product price changes" do
    # Admin changes product price from 580 to 650
    @product.update!(price: 650.0, name: "Special Pure Ghee Besan Ladoo")

    # Historical order item retains original snapshot
    @order_item.reload
    assert_equal BigDecimal("580.00"), @order_item.unit_price
    assert_equal BigDecimal("580.00"), @order_item.subtotal
    assert_equal "Besan Ladoo", @order_item.item_name
    assert_equal BigDecimal("580.00"), @order.reload.total_amount
  end

  test "product availability can be toggled without deleting" do
    assert @product.is_available?
    @product.update!(is_available: false)
    assert_not @product.reload.is_available?
    assert_equal 0, Product.available.where(id: @product.id).count
  end
end
