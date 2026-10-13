# frozen_string_literal: true

require "test_helper"

class Api::V1::AssistantControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bakarvadi = Product.create!(
      name: "Bakarvadi",
      price: 450.0,
      stock_quantity: 45,
      category: "Snacks",
      vegetarian: true,
      spice_level: "spicy",
      ingredients: "Spices",
      is_available: true
    )
  end

  test "POST /api/v1/assistant/chat returns reply and product cards" do
    post api_v1_assistant_chat_url, params: { message: "What is spicy?" }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_not_nil json["reply"]
    assert_includes json["reply"], "Bakarvadi"
    assert_not_empty json["products"]
    product_names = json["products"].map { |p| p["name"] }
    assert_includes product_names, "Bakarvadi"
  end

  test "POST /api/v1/assistant/chat returns 422 for missing message" do
    post api_v1_assistant_chat_url, params: { message: "" }, as: :json
    assert_response :unprocessable_entity
  end
end
