# frozen_string_literal: true

require "test_helper"

class Api::V1::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sweet = Product.create!(
      name: "Besan Ladoo Test",
      description: "Delicious test sweet",
      price: 580.0,
      stock_quantity: 25,
      category: "Sweets",
      is_available: true,
      preparation_time: 15,
      vegetarian: true
    )

    @snack = Product.create!(
      name: "Chakli Test",
      description: "Crispy test snack",
      price: 400.0,
      stock_quantity: 50,
      category: "Snacks",
      is_available: true,
      preparation_time: 10,
      vegetarian: true
    )

    @unavailable = Product.create!(
      name: "Out of Stock Item",
      description: "Cannot order this",
      price: 300.0,
      stock_quantity: 0,
      category: "Snacks",
      is_available: false,
      preparation_time: 10,
      vegetarian: true
    )
  end

  test "GET /api/v1/products returns only available products" do
    get "/api/v1/products"
    assert_response :success

    json = JSON.parse(response.body)
    ids = json.map { |item| item["id"] }

    assert_includes ids, @sweet.id
    assert_includes ids, @snack.id
    assert_not_includes ids, @unavailable.id

    first_item = json.find { |item| item["id"] == @sweet.id }
    assert_equal "Besan Ladoo Test", first_item["name"]
    assert_equal 580.0, first_item["price"]
    assert_equal "Sweets", first_item["category"]
    assert_equal true, first_item["is_available"]
    assert_equal 15, first_item["preparation_time"]
    assert_equal true, first_item["vegetarian"]
  end

  test "GET /api/v1/products?category=Sweets filters by category" do
    get "/api/v1/products", params: { category: "Sweets" }
    assert_response :success

    json = JSON.parse(response.body)
    names = json.map { |item| item["name"] }

    assert_includes names, "Besan Ladoo Test"
    assert_not_includes names, "Chakli Test"
  end

  test "GET /api/v1/products/:id returns single product" do
    get "/api/v1/products/#{@sweet.id}"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @sweet.id, json["id"]
    assert_equal "Besan Ladoo Test", json["name"]
    assert_equal 580.0, json["price"]
  end

  test "GET /api/v1/products/:id with invalid id returns 404 JSON" do
    get "/api/v1/products/9999999"
    assert_response :not_found

    json = JSON.parse(response.body)
    assert_equal "Resource not found", json["error"]
  end
end
