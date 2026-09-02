# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :preparation_time, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :available, -> { where(is_available: true) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id name description price stock_quantity category
      preparation_time vegetarian is_available created_at updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[order_items orders]
  end
end
