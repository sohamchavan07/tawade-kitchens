# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :preparation_time, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  UNITS = [ "per kg", "per piece", "per thali" ].freeze

  scope :available, -> { where(is_available: true) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :spicy, -> { where("LOWER(spice_level) IN (?) OR LOWER(name) IN (?)", %w[spicy medium], %w[bakarvadi sev chakli]) }
  scope :veg, -> { where(vegetarian: true) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id name description price stock_quantity category unit
      preparation_time vegetarian is_available ingredients spice_level
      created_at updated_at
    ]
  end

  def as_catalog_json
    {
      id: id,
      name: name,
      price: price.to_f,
      unit: unit,
      category: category,
      vegetarian: vegetarian,
      is_available: is_available,
      stock_quantity: stock_quantity,
      preparation_time: preparation_time,
      ingredients: ingredients,
      spice_level: spice_level || "mild",
      description: description,
      image_url: image_url
    }
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[order_items orders]
  end
end
