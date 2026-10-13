# frozen_string_literal: true

module Api
  module V1
    class WhatsappController < ActionController::API
      # GET /api/v1/whatsapp/webhook (Meta Webhook Verification)
      def verify
        verify_token = ENV.fetch("WHATSAPP_VERIFY_TOKEN", "tawade_kitchen_token")
        mode = params["hub.mode"]
        token = params["hub.verify_token"]
        challenge = params["hub.challenge"]

        if mode == "subscribe" && token == verify_token
          render plain: challenge, status: :ok
        else
          render json: { error: "Verification failed" }, status: :forbidden
        end
      end

      # POST /api/v1/whatsapp/webhook (Handle Incoming Messages)
      def webhook
        message_data = extract_message_data(params)

        if message_data[:text].blank?
          render json: { status: "ignored", reason: "no message text found" }, status: :ok
          return
        end

        result = WhatsappMessageParser.new(
          sender_phone: message_data[:phone],
          text: message_data[:text],
          sender_name: message_data[:name]
        ).call

        render json: {
          status: "success",
          action: result[:action],
          order_number: result[:order_number],
          reply: result[:reply]
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error("WhatsApp webhook error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        render json: {
          status: "error",
          error: e.message,
          reply: "सध्या सर्व्हरवर अडचण येत आहे. कृपया थोड्या वेळाने प्रयत्न करा किंवा थेट संपर्क साधा."
        }, status: :ok
      end

      private

      def extract_message_data(p)
        # 1. Direct API / simplified testing format: { phone: "...", message: "...", name: "..." }
        if p[:message].present? || p[:text].present? || p[:body].present?
          return {
            phone: p[:phone] || p[:from] || p[:customer_phone],
            text: p[:message] || p[:text] || p[:body],
            name: p[:name] || p[:customer_name] || "Customer"
          }
        end

        # 2. Standard Meta Cloud API webhook format:
        # { entry: [ { changes: [ { value: { messages: [ { text: { body: "..." } } ], contacts: [ ... ] } } ] } ] }
        entry = p[:entry]&.first
        change = entry&.dig(:changes)&.first
        value = change&.dig(:value)

        messages = value&.dig(:messages)
        first_msg = messages&.first

        if first_msg
          contact = value&.dig(:contacts)&.first
          name = contact&.dig(:profile, :name) || "Customer"
          phone = first_msg[:from] || contact&.dig(:wa_id)
          text = first_msg.dig(:text, :body)

          return { phone: phone, text: text, name: name }
        end

        # 3. Twilio format: { From: "whatsapp:+919860002903", Body: "..." }
        if p[:Body].present?
          phone = p[:From].to_s.sub("whatsapp:", "")
          return {
            phone: phone,
            text: p[:Body],
            name: p[:ProfileName] || "Customer"
          }
        end

        { phone: nil, text: nil, name: nil }
      end
    end
  end
end
