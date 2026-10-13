# frozen_string_literal: true

class WhatsappMessageParser
  attr_reader :sender_phone, :text, :sender_name

  def initialize(sender_phone:, text:, sender_name: nil)
    @sender_phone = normalize_phone(sender_phone)
    @text = text.to_s.strip
    @sender_name = sender_name.to_s.strip.presence || "Customer"
  end

  def call
    clean_text = text.downcase.strip

    if menu_command?(clean_text)
      handle_menu
    elsif status_command?(clean_text)
      handle_status(clean_text)
    elsif order_command?(clean_text)
      handle_order(clean_text)
    else
      handle_faq_or_help
    end
  end

  private

  def menu_command?(input)
    %w[menu सूची यादी list food items].include?(input) ||
      input.start_with?("menu ") ||
      input == "menu?"
  end

  def status_command?(input)
    input == "status" ||
      input.start_with?("status ") ||
      input.start_with?("order status") ||
      input.start_with?("स्थिती") ||
      input.start_with?("tk-")
  end

  def order_command?(input)
    input.start_with?("order ") ||
      input.start_with?("order:") ||
      input.match?(/\A\d+\s+[\w\s]+/)
  end

  def handle_menu
    products = Product.available.order(:category, :name)
    if products.empty?
      return {
        action: "menu",
        reply: "सध्या कोणतेही पदार्थ उपलब्ध नाहीत. कृपया नंतर पुन्हा प्रयत्न करा. 🙏\n(No items currently available. Please check back later!)"
      }
    end

    lines = [
      "✨ *Tawade Kitchen - आजचा मेनू (Menu)* ✨",
      "फक्त दुकानातून पिकअप (Pickup Only)",
      "---------------------------------"
    ]

    current_cat = nil
    products.each do |p|
      if p.category != current_cat
        current_cat = p.category
        lines << ""
        lines << "*[ #{current_cat} ]*"
      end
      lines << "• #{p.name} - ₹#{format('%.2f', p.price)}"
    end

    lines += [
      "---------------------------------",
      "ऑर्डर देण्यासाठी मेसेज करा: *order <संख्या> <पदार्थ> + <संख्या> <पदार्थ>*",
      "उदा: *order 2 besan ladoo + 1 chakli*",
      "स्थिती तपासण्यासाठी: *status*"
    ]

    {
      action: "menu",
      reply: lines.join("\n")
    }
  end

  def handle_status(input)
    order_number = extract_order_number(input)

    order = if order_number.present?
              Order.find_by("LOWER(order_number) = ?", order_number.downcase)
            elsif sender_phone.present?
              Order.where(customer_phone: sender_phone).order(created_at: :desc).first
            end

    if order.nil?
      return {
        action: "status",
        reply: "तुमची कोणतीही चालू ऑर्डर सापडली नाही.\nऑर्डर क्रमांक तपासून पुन्हा पाठवा (उदा. *status TK-20261013-ABCD*).\n(No order found for this number. Check your order number and try again.)"
      }
    end

    status_marathi = {
      "pending" => "प्रतीक्षेत (Pending Confirmation)",
      "confirmed" => "स्वीकारली (Confirmed)",
      "preparing" => "तयार होत आहे (Preparing)",
      "ready_for_pickup" => "पिकअपसाठी तयार (Ready for Pickup)",
      "collected" => "घेतली (Collected)",
      "cancelled" => "रद्द झाली (Cancelled)"
    }[order.status] || order.status

    payment_marathi = {
      "pending" => "बाकी (Pending)",
      "submitted" => "पडताळणी बाकी (Awaiting Verification)",
      "verified" => "यशस्वी (Verified)",
      "failed" => "अयशस्वी (Failed)",
      "refunded" => "रिफंड (Refunded)"
    }[order.payment_status] || order.payment_status

    reply = [
      "📦 *ऑर्डर स्थिती (Order Status)* 📦",
      "ऑर्डर क्रमांक: *##{order.order_number}*",
      "स्थिती: *#{status_marathi}*",
      "पेमेंट स्थिती: *#{payment_marathi}*",
      "पिकअप वेळ: *#{order.pickup_date} at #{order.pickup_time}*",
      "एकूण रक्कम: *₹#{format('%.2f', order.total_amount)}*",
      "---------------------------------",
      "पिकअप पत्ता: #{default_pickup_address}",
      "मदतीसाठी: +91 #{default_whatsapp_number}"
    ].join("\n")

    {
      action: "status",
      order_number: order.order_number,
      order: order,
      reply: reply
    }
  end

  def handle_order(input)
    order_content = input.sub(/\A(order\s*:?|ऑर्डर\s*:?)\s*/i, "").strip

    if order_content.blank?
      return {
        action: "order_failed",
        reply: "कृपया ऑर्डरचे पदार्थ आणि संख्या नमूद करा.\nउदा: *order 2 besan ladoo + 1 chakli*\n(Please specify items and quantities, e.g. 'order 2 besan ladoo + 1 chakli')"
      }
    end

    parsed_items, parse_errors = parse_order_items(order_content)

    if parse_errors.any?
      return {
        action: "order_failed",
        errors: parse_errors,
        reply: "⚠️ ऑर्डर समजण्यात अडचण आली:\n• #{parse_errors.join("\n• ")}\n\nकृपया मेनू पाहण्यासाठी *menu* पाठवा किंवा *order 2 besan ladoo + 1 chakli* या स्वरूपात पाठवा."
      }
    end

    if parsed_items.empty?
      return {
        action: "order_failed",
        reply: "कोणतेही वैध पदार्थ सापडले नाहीत. उपलब्ध पदार्थांसाठी *menu* पाठवा."
      }
    end

    pickup_date, pickup_time = calculate_default_pickup_schedule

    order_params = {
      customer_name: sender_name,
      customer_phone: sender_phone,
      pickup_date: pickup_date,
      pickup_time: pickup_time,
      payment_method: "pay_at_pickup",
      notes: "Ordered via WhatsApp",
      items: parsed_items.map { |item| { product_id: item[:product].id, quantity: item[:quantity] } }
    }

    # Strict price recalculation & validation via OrderCreator
    result = OrderCreator.new(order_params).call

    if result[:success]
      order = result[:order]
      items_summary = order.order_items.map do |oi|
        "• #{oi.item_name} × #{oi.quantity} = ₹#{format('%.2f', oi.subtotal)}"
      end

      reply = [
        "🎉 *तुमची पिकअप ऑर्डर नोंदवली गेली आहे!* 🎉",
        "ऑर्डर क्रमांक: *##{order.order_number}*",
        "ग्राहक: #{order.customer_name}",
        "पिकअप वेळ: *#{order.pickup_date} at #{order.pickup_time}*",
        "---------------------------------",
        "*ऑर्डर केलेले पदार्थ:*",
        items_summary.join("\n"),
        "---------------------------------",
        "एकूण देय रक्कम: *₹#{format('%.2f', order.total_amount)}*",
        "पेमेंट: दुकानात पिकअप करताना द्या (Pay at Pickup)",
        "---------------------------------",
        "पिकअप पत्ता: #{default_pickup_address}",
        "स्थिती तपासण्यासाठी: *status #{order.order_number}*"
      ].join("\n")

      {
        action: "order_created",
        order_number: order.order_number,
        order: order,
        reply: reply
      }
    else
      {
        action: "order_failed",
        errors: result[:errors],
        reply: "⚠️ ऑर्डर पूर्ण होऊ शकली नाही:\n• #{result[:errors].join("\n• ")}\n\nकृपया खात्री करून पुन्हा प्रयत्न करा किंवा आम्हाला थेट कॉल करा."
      }
    end
  end

  def handle_faq_or_help
    lines = [
      "🙏 *Tawade Kitchen मध्ये आपले स्वागत आहे!*",
      "आम्ही कोल्हापूरचे अस्सल घरगुती पारंपरिक फराळ आणि मिठाई देतो.",
      "",
      "*उपलब्ध आज्ञा (Commands):*",
      "1️⃣ *menu* - आजचे सर्व पदार्थ आणि दर पहा",
      "2️⃣ *order 2 besan ladoo + 1 chakli* - थेट ऑर्डर द्या",
      "3️⃣ *status* किंवा *status <ऑर्डर नंबर>* - ऑर्डरची स्थिती तपासा",
      "",
      "📍 *पत्ता:* #{default_pickup_address}",
      "⏰ *वेळ:* #{default_operating_hours}",
      "📞 *मदतीसाठी संपर्क:* +91 #{default_whatsapp_number}"
    ]

    {
      action: "faq",
      reply: lines.join("\n")
    }
  end

  def parse_order_items(content)
    # Split by '+', ',', 'and', or newlines
    tokens = content.split(/\s*(?:\+|\band\b|,|\n)\s*/i).map(&:strip).reject(&:blank?)
    parsed = []
    errors = []

    available_products = Product.all.to_a

    tokens.each do |token|
      # Look for pattern: <quantity> <product name> or <product name> <quantity>
      match_prefix = token.match(/\A(\d+)\s*(?:x|plates?|packs?|kg|gm)?\s*(.+)\z/i)
      match_suffix = token.match(/\A(.+?)\s*(\d+)\s*(?:x|plates?|packs?|kg|gm)?\z/i)

      if match_prefix
        qty = match_prefix[1].to_i
        query_name = match_prefix[2].strip
      elsif match_suffix
        query_name = match_suffix[1].strip
        qty = match_suffix[2].to_i
      else
        errors << "पदार्थाची संख्या समजली नाही: '#{token}' (उदा. 2 pav bhaji)"
        next
      end

      if qty <= 0
        errors << "संख्या 0 पेक्षा जास्त असावी: '#{token}'"
        next
      end

      matched_product = match_product(query_name, available_products)

      if matched_product.nil?
        errors << "पदार्थ सापडला नाही: '#{query_name}'. उपलब्ध पदार्थांसाठी 'menu' पाठवा."
      else
        parsed << { product: matched_product, quantity: qty }
      end
    end

    [parsed, errors]
  end

  def match_product(query, products)
    normalized = query.downcase.gsub(/[^a-z0-9\s]/, "").strip
    return nil if normalized.blank?

    # 1. Exact match on normalized product name
    match = products.find { |p| p.name.downcase.gsub(/[^a-z0-9\s]/, "").strip == normalized }
    return match if match

    # 2. Substring match
    match = products.find { |p| p.name.downcase.include?(normalized) || normalized.include?(p.name.downcase) }
    return match if match

    # 3. Keyword / partial tokens
    tokens = normalized.split(/\s+/)
    match = products.find do |p|
      p_name = p.name.downcase
      tokens.any? { |t| t.length >= 3 && p_name.include?(t) }
    end

    match
  end

  def extract_order_number(input)
    match = input.match(/TK-\d{8}-[A-Z0-9]{4}/i)
    match ? match[0].upcase : nil
  end

  def calculate_default_pickup_schedule
    tz = Rails.application.config.pickup_schedule&.dig(:timezone) || "Asia/Kolkata"
    current_time = Time.current.in_time_zone(tz)
    date = current_time.to_date

    # Pickup slot roughly 1 hour ahead rounded to 30 mins
    target_time = current_time + 1.hour
    mins = target_time.min
    rounded_mins = (mins >= 30) ? 30 : 0
    slot_time = target_time.change(min: rounded_mins)

    start_str = Rails.application.config.pickup_schedule&.dig(:operating_hours, :start_time) || "09:00"
    end_str = Rails.application.config.pickup_schedule&.dig(:operating_hours, :end_time) || "20:00"

    start_h, start_m = start_str.split(":").map(&:to_i)
    end_h, end_m = end_str.split(":").map(&:to_i)

    # Bound within operating hours
    if slot_time.hour < start_h || (slot_time.hour == start_h && slot_time.min < start_m)
      slot_time = slot_time.change(hour: start_h, min: start_m)
    elsif slot_time.hour > end_h || (slot_time.hour == end_h && slot_time.min > end_m)
      # Scheduled for opening next day
      date = date + 1.day
      slot_time = slot_time.change(hour: start_h, min: start_m)
    end

    time_str = slot_time.strftime("%I:%M %p")
    [date.iso8601, time_str]
  end

  def normalize_phone(phone)
    return "9860002903" if phone.blank?
    cleaned = phone.to_s.gsub(/[\s\-()+]/, "")
    cleaned = cleaned.sub(/\A91/, "") if cleaned.start_with?("91") && cleaned.length == 12
    cleaned = cleaned.sub(/\A0/, "") if cleaned.start_with?("0") && cleaned.length == 11
    cleaned.presence || "9860002903"
  end

  def default_pickup_address
    Rails.application.config.pickup_schedule&.dig(:address) || "Plot no 7, Mukt Sainik Vasahat, Kolhapur"
  end

  def default_operating_hours
    Rails.application.config.pickup_schedule&.dig(:operating_hours, :display) || "9:00 AM - 8:00 PM IST"
  end

  def default_whatsapp_number
    Rails.application.config.pickup_schedule&.dig(:whatsapp_number) || "9860002903"
  end
end
