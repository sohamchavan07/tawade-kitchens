# frozen_string_literal: true

ActiveAdmin.register Order do
  menu priority: 2, label: "Orders (पिकअप ऑर्डर्स)"

  permit_params :status, :payment_status, :payment_reference, :notes

  config.sort_order = "created_at_desc"

  # Scopes for rapid fulfillment workflow
  scope :all, default: true
  scope("प्रतीक्षेत (Pending)") { |orders| orders.where(status: "pending") }
  scope("कन्फर्म (Confirmed)") { |orders| orders.where(status: "confirmed") }
  scope("तयार होत आहे (Preparing)") { |orders| orders.where(status: "preparing") }
  scope("पिकअपसाठी तयार (Ready)") { |orders| orders.where(status: "ready_for_pickup") }
  scope("पडताळणी बाकी (Payment Submitted)") { |orders| orders.where(payment_status: "submitted") }
  scope("पूर्ण (Collected)") { |orders| orders.where(status: "collected") }
  scope("रद्द (Cancelled)") { |orders| orders.where(status: "cancelled") }

  # Member Actions for Order Status Transitions
  member_action :confirm_order, method: :put do
    resource.transition_to_status!("confirmed")
    redirect_to admin_order_path(resource), notice: "Order ##{resource.order_number} confirmed successfully. You may now send payment instructions if paying online."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to update order status: #{e.message}"
  end

  member_action :prepare_order, method: :put do
    resource.transition_to_status!("preparing")
    redirect_to admin_order_path(resource), notice: "Order ##{resource.order_number} marked as preparing in kitchen."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to update order status: #{e.message}"
  end

  member_action :ready_order, method: :put do
    resource.transition_to_status!("ready_for_pickup")
    redirect_to admin_order_path(resource), notice: "Order ##{resource.order_number} marked as ready for pickup."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to update order status: #{e.message}"
  end

  member_action :mark_collected, method: :put do
    resource.transition_to_status!("collected")
    redirect_to admin_order_path(resource), notice: "Order ##{resource.order_number} marked as collected by customer."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to update order status: #{e.message}"
  end

  member_action :cancel_order, method: :put do
    resource.transition_to_status!("cancelled")
    redirect_to admin_order_path(resource), alert: "Order ##{resource.order_number} cancelled."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to cancel order: #{e.message}"
  end

  # Member Action to Record Customer UTR (moves status from pending -> submitted)
  member_action :record_utr, method: :put do
    utr = params[:payment_reference].to_s.strip
    resource.record_payment_reference!(utr)
    redirect_to admin_order_path(resource), notice: "Payment reference recorded successfully. Payment status updated to 'submitted'. Please verify in Tawade Kitchen bank account before marking verified."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to record payment reference: #{e.message}"
  end

  # Member Actions for Manual Payment Verification
  member_action :verify_payment, method: :put do
    resource.transition_to_payment_status!("verified")
    redirect_to admin_order_path(resource), notice: "Payment for Order ##{resource.order_number} manually verified."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to verify payment: #{e.message}"
  end

  member_action :reject_payment, method: :put do
    resource.transition_to_payment_status!("failed")
    redirect_to admin_order_path(resource), alert: "Payment for Order ##{resource.order_number} marked as failed."
  rescue StandardError => e
    redirect_to admin_order_path(resource), alert: "Failed to update payment status: #{e.message}"
  end

  # Action Item Buttons on Show Page
  action_item :confirm, only: :show, if: proc { resource.can_transition_to_status?("confirmed") && resource.status == "pending" } do
    link_to "Confirm Order", confirm_order_admin_order_path(resource), method: :put, class: "button"
  end

  action_item :prepare, only: :show, if: proc { resource.can_transition_to_status?("preparing") && resource.status == "confirmed" } do
    link_to "Start Preparing", prepare_order_admin_order_path(resource), method: :put, class: "button"
  end

  action_item :ready, only: :show, if: proc { resource.can_transition_to_status?("ready_for_pickup") && resource.status == "preparing" } do
    link_to "Mark Ready for Pickup", ready_order_admin_order_path(resource), method: :put, class: "button"
  end

  action_item :collected, only: :show, if: proc { resource.can_transition_to_status?("collected") && resource.status == "ready_for_pickup" } do
    link_to "Mark Collected", mark_collected_admin_order_path(resource), method: :put, data: { confirm: "Are you sure this order has been collected by the customer?" }, class: "button"
  end

  action_item :cancel, only: :show, if: proc { resource.can_transition_to_status?("cancelled") } do
    link_to "Cancel Order", cancel_order_admin_order_path(resource), method: :put, data: { confirm: "Are you sure you want to cancel this pickup order?" }, class: "button"
  end

  # Staff-only action: Open pre-filled WhatsApp payment instructions (only after confirmation, when pending)
  action_item :send_whatsapp_instructions, only: :show, if: proc {
    resource.status != "pending" && resource.status != "cancelled" &&
      resource.payment_status == "pending" &&
      (resource.payment_method == "upi_after_confirmation" || resource.payment_method == "upi")
  } do
    raw_phone = resource.customer_phone.to_s.gsub(/[\s\-()+]/, "")
    phone = raw_phone.start_with?("91") ? raw_phone : "91#{raw_phone}"
    upi_id = Rails.application.config.pickup_schedule&.dig(:upi_id) || "tawadekitchen@upi"
    store_address = Rails.application.config.pickup_schedule&.dig(:address)

    msg = [
      "🪔 *Tawade Kitchen - ऑर्डर कन्फर्मेशन व पेमेंट तपशील*",
      "नमस्कार #{resource.customer_name}!",
      "आपली ऑर्डर *##{resource.order_number}* कन्फर्म झाली आहे. सर्व पदार्थ ताजे तयार केले जात आहेत.",
      "---------------------------------",
      "देय एकूण रक्कम: *₹#{resource.total_amount}*",
      "पिकअप वेळ: *#{resource.pickup_date} at #{resource.pickup_time}*",
      "---------------------------------",
      "कृपया खालील अधिकृत UPI ID वर पेमेंट करावे:",
      "👉 UPI ID: *#{upi_id}*",
      "---------------------------------",
      "पेमेंट पूर्ण झाल्यावर याच WhatsApp चॅटवर *Transaction ID (UTR)* रिप्लाय करा.",
      "पत्ता: #{store_address}",
      "धन्यवाद! 🙏"
    ].join("\n")

    wa_url = "https://wa.me/#{phone}?text=#{ERB::Util.url_encode(msg)}"

    link_to "Send WhatsApp Payment Instructions",
            wa_url,
            target: "_blank",
            rel: "noopener noreferrer",
            class: "button",
            data: { confirm: "⚠️ Staff Notice: Verify customer phone (+#{phone}) and order amount (₹#{resource.total_amount}) before sending payment instructions. Open WhatsApp now?" }
  end

  action_item :verify_pay, only: :show, if: proc {
    resource.can_transition_to_payment_status?("verified") &&
      resource.status != "pending" &&
      (resource.payment_method != "upi_after_confirmation" || resource.payment_status == "submitted")
  } do
    link_to "Verify Payment", verify_payment_admin_order_path(resource), method: :put, data: { confirm: "Confirm you have verified this payment in Tawade Kitchen bank/UPI account?" }, class: "button"
  end

  action_item :reject_pay, only: :show, if: proc {
    resource.can_transition_to_payment_status?("failed") && resource.payment_status == "submitted"
  } do
    link_to "Mark Payment Failed", reject_payment_admin_order_path(resource), method: :put, data: { confirm: "Are you sure you want to mark this payment as failed?" }, class: "button"
  end

  # Index View
  index do
    selectable_column
    column "Order No", :order_number do |order|
      link_to order.order_number, admin_order_path(order)
    end
    column "Customer", :customer_name
    column "Phone (Admin Only)", :customer_phone
    column "Pickup Schedule" do |order|
      "#{order.pickup_date} at #{order.pickup_time}"
    end
    column "Total", :total_amount do |order|
      number_to_currency(order.total_amount, unit: "₹")
    end
    column "Order Status", :status do |order|
      case order.status
      when "pending" then status_tag(order.status, class: "orange")
      when "confirmed" then status_tag(order.status, class: "blue")
      when "preparing" then status_tag(order.status, class: "yellow")
      when "ready_for_pickup" then status_tag(order.status, class: "green")
      when "collected" then status_tag(order.status, class: "ok")
      when "cancelled" then status_tag(order.status, class: "red")
      else status_tag(order.status)
      end
    end
    column "Payment Method", :payment_method do |order|
      case order.payment_method
      when "upi_after_confirmation"
        status_tag("UPI (After Confirmation)", class: "blue")
      when "pay_at_pickup"
        status_tag("Pay at Pickup", class: "green")
      else
        status_tag("Legacy UPI", class: "orange")
      end
    end
    column "Payment Status", :payment_status do |order|
      case order.payment_status
      when "submitted" then status_tag("Awaiting Verification", class: "orange")
      when "verified" then status_tag("Verified", class: "ok")
      when "failed" then status_tag("Failed", class: "red")
      when "refunded" then status_tag("Refunded", class: "red")
      else status_tag(order.payment_status)
      end
    end
    column "UTR / Ref", :payment_reference
    column "Created At", :created_at
    actions
  end

  # Show View
  show title: proc { |order| "Pickup Order #{order.order_number}" } do
    attributes_table title: "Order & Pickup Details" do
      row :order_number
      row "Customer Name", &:customer_name
      row "Customer Phone (Admin)", &:customer_phone
      row :status do |order|
        status_tag order.status
      end
      row :pickup_date
      row :pickup_time
      row "Pickup Store Location" do
        Rails.application.config.pickup_schedule&.dig(:address)
      end
      row "Operating Hours" do
        Rails.application.config.pickup_schedule&.dig(:operating_hours, :display)
      end
      row :payment_method do |order|
        case order.payment_method
        when "upi_after_confirmation" then "Online UPI (After Confirmation)"
        when "pay_at_pickup" then "Pay at Pickup Counter"
        else "Legacy UPI"
        end
      end
      row :payment_status do |order|
        status_tag order.payment_status
      end
      row "UPI Reference / UTR", &:payment_reference
      row :total_amount do |order|
        number_to_currency(order.total_amount, unit: "₹")
      end
      row :notes
      row :created_at
      row :updated_at
    end

    # Panel to record UTR received from customer (available once order is confirmed and payment is pending)
    if order.status != "pending" && order.status != "cancelled" && order.payment_status == "pending"
      panel "Record Customer UTR / Payment Reference (पेमेंट UTR नोंदवा)" do
        form action: record_utr_admin_order_path(order), method: :post do
          input type: :hidden, name: "_method", value: "put"
          input type: :hidden, name: "authenticity_token", value: form_authenticity_token
          div style: "display: flex; gap: 12px; align-items: center; padding: 10px 0;" do
            label "Customer UTR / Transaction ID (from WhatsApp):", style: "font-weight: 600; font-size: 13px;"
            input type: :text, name: "payment_reference", placeholder: "उदा. 423456789012 (12-digit UTR)", required: true, style: "padding: 6px 12px; width: 300px; border: 1px solid #cbd5e1; border-radius: 6px;"
            input type: :submit, value: "Record UTR & Mark Submitted", class: "button"
          end
          p "⚠️ Note: Recording the UTR sets payment status to 'submitted'. Staff must check the Tawade Kitchen bank account before clicking 'Verify Payment'.", style: "font-size: 12px; color: #64748b; margin-top: 6px;"
        end
      end
    end

    panel "Order Items (पदार्थ तपशील)" do
      table_for order.order_items do
        column "Item Name", :item_name
        column "Unit Price" do |item|
          number_to_currency(item.unit_price, unit: "₹")
        end
        column "Quantity", :quantity
        column "Subtotal" do |item|
          number_to_currency(item.subtotal, unit: "₹")
        end
      end
    end
  end

  # Filters
  filter :order_number
  filter :status, as: :select, collection: Order::STATUSES
  filter :payment_status, as: :select, collection: Order::PAYMENT_STATUSES
  filter :payment_method, as: :select, collection: Order::PAYMENT_METHODS
  filter :pickup_date
  filter :created_at
end
