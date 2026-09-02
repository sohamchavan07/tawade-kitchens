# frozen_string_literal: true

require "bigdecimal"

class OrderCreator
  MAX_QUANTITY_PER_ITEM = 50
  MAX_TOTAL_ITEMS = 100
  MAX_TOTAL_AMOUNT = BigDecimal("100000.00")

  attr_reader :params, :errors, :order

  def initialize(params)
    @params = params.to_h.with_indifferent_access
    @errors = []
    @order = nil
  end

  def call
    validate_and_build
    return failure_result if @errors.any?

    save_order_transaction
  end

  private

  def validate_and_build
    validate_customer_name
    validate_customer_phone
    validate_pickup_date
    validate_pickup_time
    validate_payment_details
    validate_items_and_build_associations
  end

  def validate_customer_name
    name = params[:customer_name].to_s.strip
    if name.blank? || name.length < 2
      @errors << "Customer name is required and must be at least 2 characters"
    elsif name.length > 100
      @errors << "Customer name cannot exceed 100 characters"
    end
  end

  def validate_customer_phone
    phone = params[:customer_phone].to_s.strip
    @normalized_phone = normalize_phone(phone)

    if @normalized_phone.blank? || !valid_indian_phone?(@normalized_phone)
      @errors << "Customer phone must be a valid 10-digit Indian mobile number (e.g. 9860002903)"
    end
  end

  def normalize_phone(phone)
    return "" if phone.blank?

    cleaned = phone.gsub(/[\s\-()+]/, "")
    if cleaned.start_with?("91") && cleaned.length == 12
      cleaned = cleaned[2..]
    elsif cleaned.start_with?("0") && cleaned.length == 11
      cleaned = cleaned[1..]
    end
    cleaned
  end

  def valid_indian_phone?(phone)
    phone.match?(/\A[6-9]\d{9}\z/)
  end

  def validate_pickup_date
    date_input = params[:pickup_date]
    if date_input.blank?
      @errors << "Pickup date is required"
      return
    end

    @parsed_pickup_date = begin
      date_input.is_a?(Date) ? date_input : Date.iso8601(date_input.to_s)
    rescue ArgumentError
      @errors << "Pickup date format is invalid. Expected YYYY-MM-DD"
      return
    end

    schedule_tz = Rails.application.config.pickup_schedule&.dig(:timezone) || "Asia/Kolkata"
    today = Time.current.in_time_zone(schedule_tz).to_date

    if @parsed_pickup_date < today
      @errors << "Pickup date cannot be in the past"
    elsif @parsed_pickup_date > today + 30.days
      @errors << "Pickup date cannot be more than 30 days in advance"
    end
  end

  def validate_pickup_time
    time_str = params[:pickup_time].to_s.strip
    if time_str.blank?
      @errors << "Pickup time is required"
      return
    end

    operating_hours = Rails.application.config.pickup_schedule&.dig(:operating_hours) || { start_time: "09:00", end_time: "20:00" }
    start_minutes = time_to_minutes(operating_hours[:start_time])
    end_minutes = time_to_minutes(operating_hours[:end_time])

    slot_minutes = parse_time_slot_minutes(time_str)
    if slot_minutes.nil?
      @errors << "Pickup time format is invalid"
      return
    end

    if slot_minutes < start_minutes || slot_minutes > end_minutes
      @errors << "Pickup time must be within operating hours (#{operating_hours[:start_time]} to #{operating_hours[:end_time]})"
    end

    @normalized_pickup_time = format_pickup_time(slot_minutes)
  end

  def time_to_minutes(time_str)
    parts = time_str.to_s.split(":")
    return 0 if parts.length < 2

    (parts[0].to_i * 60) + parts[1].to_i
  end

  def parse_time_slot_minutes(time_str)
    clean = time_str.strip.upcase
    match_12h = clean.match(/\A(\d{1,2}):(\d{2})\s*(AM|PM)?\z/)

    return nil unless match_12h

    hours = match_12h[1].to_i
    minutes = match_12h[2].to_i
    meridiem = match_12h[3]

    if meridiem
      return nil if hours < 1 || hours > 12 || minutes < 0 || minutes > 59
      hours = 0 if hours == 12 && meridiem == "AM"
      hours += 12 if hours < 12 && meridiem == "PM"
    else
      return nil if hours < 0 || hours > 23 || minutes < 0 || minutes > 59
    end

    (hours * 60) + minutes
  end

  def format_pickup_time(minutes)
    h = minutes / 60
    m = minutes % 60
    period = h >= 12 ? "PM" : "AM"
    h12 = h % 12
    h12 = 12 if h12.zero?
    format("%02d:%02d %s", h12, m, period)
  end

  def validate_payment_details
    method = params[:payment_method].to_s.strip
    unless Order::NEW_PAYMENT_METHODS.include?(method)
      @errors << "Invalid payment method. Allowed methods: #{Order::NEW_PAYMENT_METHODS.join(', ')}"
      return
    end

    @payment_method = method
    @payment_status = "pending"
    @payment_reference = nil
  end

  def validate_items_and_build_associations
    raw_items = params[:items]
    unless raw_items.is_a?(Array) && raw_items.any?
      @errors << "Order must contain at least one item"
      return
    end

    if raw_items.length > 50
      @errors << "Order cannot contain more than 50 distinct items"
      return
    end

    product_ids = []
    quantities = {}

    raw_items.each_with_index do |item_data, idx|
      unless item_data.is_a?(Hash) || item_data.is_a?(ActionController::Parameters)
        @errors << "Item ##{idx + 1} format is invalid"
        next
      end

      pid = item_data[:product_id] || item_data[:productId]
      qty = item_data[:quantity]

      if pid.blank? || !pid.to_s.match?(/\A\d+\z/)
        @errors << "Item ##{idx + 1} has an invalid or missing product ID"
        next
      end

      if qty.blank? || !qty.to_s.match?(/\A\d+\z/) || qty.to_i <= 0
        @errors << "Quantity for product ID #{pid} must be a positive integer"
        next
      end

      qty_int = qty.to_i
      if qty_int > MAX_QUANTITY_PER_ITEM
        @errors << "Quantity for product ID #{pid} cannot exceed #{MAX_QUANTITY_PER_ITEM} units"
        next
      end

      pid_int = pid.to_i
      product_ids << pid_int
      quantities[pid_int] = (quantities[pid_int] || 0) + qty_int
    end

    return if @errors.any?

    total_units = quantities.values.sum
    if total_units > MAX_TOTAL_ITEMS
      @errors << "Total order quantity cannot exceed #{MAX_TOTAL_ITEMS} items"
      return
    end

    # Fetch products from database
    products = Product.where(id: product_ids.uniq).index_by(&:id)

    missing_ids = product_ids.uniq - products.keys
    if missing_ids.any?
      @errors << "The following product IDs do not exist: #{missing_ids.join(', ')}"
      return
    end

    @order_items_data = []
    total_amount = BigDecimal("0.0")

    quantities.each do |pid, qty|
      product = products[pid]

      unless product.is_available?
        @errors << "Product '#{product.name}' is currently out of stock / unavailable for order"
        next
      end

      unit_price = BigDecimal(product.price.to_s)
      subtotal = unit_price * BigDecimal(qty.to_s)
      total_amount += subtotal

      @order_items_data << {
        product: product,
        item_name: product.name,
        unit_price: unit_price,
        quantity: qty,
        subtotal: subtotal
      }
    end

    if total_amount > MAX_TOTAL_AMOUNT
      @errors << "Order total amount exceeds maximum permitted limit of ₹#{MAX_TOTAL_AMOUNT}"
    end

    @recalculated_total = total_amount
  end

  def save_order_transaction
    retries = 0

    begin
      Order.transaction do
        @order = Order.new(
          customer_name: params[:customer_name].to_s.strip,
          customer_phone: @normalized_phone,
          pickup_date: @parsed_pickup_date,
          pickup_time: @normalized_pickup_time,
          payment_method: @payment_method,
          payment_status: @payment_status,
          payment_reference: @payment_reference,
          notes: params[:notes].to_s.strip.presence,
          status: "pending",
          total_amount: @recalculated_total
        )

        @order_items_data.each do |item_attrs|
          @order.order_items.build(item_attrs)
        end

        @order.save!
      end

      { success: true, order: @order }
    rescue ActiveRecord::RecordNotUnique => e
      retries += 1
      if retries <= 3
        @order = nil
        retry
      else
        @errors << "Could not generate a unique order number. Please try again."
        failure_result
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors += e.record.errors.full_messages
      failure_result
    rescue StandardError => e
      Rails.logger.error("Order creation unexpected error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      @errors << "An error occurred while processing your order: #{e.message}"
      failure_result
    end
  end

  def failure_result
    { success: false, errors: @errors }
  end
end
