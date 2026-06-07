class WhatsappConfirmationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    customer = order.customer

    # Logic to send WhatsApp message via Gupshup/Twilio
    # For now, we'll just log it
    Rails.logger.info "Sending WhatsApp confirmation to #{customer.phone} for Order ##{order.id}"

    # Example using a fictional client:
    # GupshupClient.send_message(
    #   to: customer.phone,
    #   message: "Hi #{customer.name}, your order for ₹#{order.total_amount} at Tawade Kitchen is confirmed!"
    # )
  end
end
