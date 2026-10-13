# frozen_string_literal: true

require "test_helper"

class MenuAssistantServiceTest < ActiveSupport::TestCase
  setup do
    @besan_ladoo = Product.create!(
      name: "Besan Ladoo",
      price: 580.0,
      stock_quantity: 50,
      category: "Sweets",
      vegetarian: true,
      spice_level: "mild",
      ingredients: "Gram flour, cow ghee, sugar, cardamom",
      is_available: true
    )

    @bakarvadi = Product.create!(
      name: "Bakarvadi",
      price: 450.0,
      stock_quantity: 45,
      category: "Snacks",
      vegetarian: true,
      spice_level: "spicy",
      ingredients: "Gram flour, roasted dry coconut, spices, chilli",
      is_available: true
    )

    @sev = Product.create!(
      name: "Sev",
      price: 350.0,
      stock_quantity: 70,
      category: "Snacks",
      vegetarian: true,
      spice_level: "spicy",
      ingredients: "Gram flour, black pepper, clove, chilli",
      is_available: true
    )

    @chakli = Product.create!(
      name: "Chakli",
      price: 500.0,
      stock_quantity: 100,
      category: "Snacks",
      vegetarian: true,
      spice_level: "medium",
      ingredients: "Rice flour, cumin, ajwain, sesame",
      is_available: true
    )
  end

  test "answers 'What is spicy?' with spicy items using rule engine" do
    result = MenuAssistantService.new("What is spicy?").call
    assert_equal "rule", result[:source]
    assert_includes result[:reply], "spicy and spiced snacks"
    assert_includes result[:reply], "Bakarvadi"
    names = result[:products].map { |p| p[:name] }
    assert_includes names, "Bakarvadi"
    assert_includes names, "Sev"
  end

  test "answers 'Do you have vegetarian options?'" do
    result = MenuAssistantService.new("Do you have vegetarian options?").call
    assert_equal "rule", result[:source]
    assert_includes result[:reply], "vegetarian"
    assert_not_empty result[:products]
  end

  test "answers price budget queries like 'What is under 400?'" do
    result = MenuAssistantService.new("What is under 400?").call
    assert_equal "rule", result[:source]
    names = result[:products].map { |p| p[:name] }
    assert_includes names, "Sev"
    assert_not_includes names, "Besan Ladoo"
  end

  test "answers group size queries like 'Which snacks are best for 3 people?'" do
    result = MenuAssistantService.new("Which snacks are best for 3 people?").call
    assert_equal "rule", result[:source]
    assert_includes result[:reply], "For 3 people"
    assert_not_empty result[:products]
  end

  test "returns friendly message for empty query" do
    result = MenuAssistantService.new("").call
    assert_equal "rule", result[:source]
    assert_includes result[:reply], "Tawade Kitchen"
    assert_empty result[:products]
  end
end
