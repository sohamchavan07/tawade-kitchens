# frozen_string_literal: true

require "test_helper"

class Api::V1::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @besan_ladoo = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      is_available: true
    )
  end

  test "GET webhook verification succeeds with matching token" do
    get api_v1_whatsapp_webhook_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "tawade_kitchen_token",
      "hub.challenge" => "challenge_123456"
    }

    assert_response :success
    assert_equal "challenge_123456", response.body
  end

  test "GET webhook verification fails with invalid token" do
    get api_v1_whatsapp_webhook_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong_token",
      "hub.challenge" => "challenge_123456"
    }

    assert_response :forbidden
  end

  test "POST webhook handles menu query" do
    post api_v1_whatsapp_webhook_url, params: {
      phone: "9860002903",
      message: "menu"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "success", json["status"]
    assert_equal "menu", json["action"]
    assert_includes json["reply"], "Besan Ladoo"
  end

  test "POST webhook handles order creation via simple JSON payload" do
    post api_v1_whatsapp_webhook_url, params: {
      phone: "9860002903",
      name: "Prashant Patil",
      message: "order 2 besan ladoo"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "success", json["status"]
    assert_equal "order_created", json["action"]
    assert_not_nil json["order_number"]
    assert_includes json["reply"], json["order_number"]
  end

  test "POST webhook handles Meta Cloud API format" do
    meta_payload = {
      object: "whatsapp_business_account",
      entry: [
        {
          id: "123456",
          changes: [
            {
              value: {
                messaging_product: "whatsapp",
                metadata: { display_phone_number: "9860002903", phone_number_id: "111" },
                contacts: [
                  { profile: { name: "Anil Kulkarni" }, wa_id: "919860002903" }
                ],
                messages: [
                  {
                    from: "919860002903",
                    id: "wamid.123",
                    timestamp: "1700000000",
                    text: { body: "menu" },
                    type: "text"
                  }
                ]
              },
              field: "messages"
            }
          ]
        }
      ]
    }

    post api_v1_whatsapp_webhook_url, params: meta_payload, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "success", json["status"]
    assert_equal "menu", json["action"]
    assert_includes json["reply"], "Besan Ladoo"
  end
end
