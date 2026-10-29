# frozen_string_literal: true

class RemoveSadhiAndLasunSevProducts < ActiveRecord::Migration[8.0]
  def up
    Product.where(name: [ "Sadhi Sev", "Lasun Sev" ]).destroy_all
  end

  def down
    [
      {
        name: "Sadhi Sev",
        price: 400,
        unit: "per kg",
        category: "Snacks",
        stock_quantity: 70,
        description: "Traditional plain sev with classic Kolhapuri flavour.",
        preparation_time: 10,
        vegetarian: true,
        is_available: true
      },
      {
        name: "Lasun Sev",
        price: 420,
        unit: "per kg",
        category: "Snacks",
        stock_quantity: 70,
        description: "Garlic-flavoured sev with a bold, aromatic taste.",
        preparation_time: 10,
        vegetarian: true,
        is_available: true
      }
    ].each do |attrs|
      Product.create!(attrs)
    end
  end
end
