class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :set_item_name_and_subtotal

  private

  def set_item_name_and_subtotal
    self.item_name = product&.name if item_name.blank?
    self.unit_price = product&.price if product && (unit_price.blank? || unit_price.zero?)
    self.subtotal = (quantity || 1) * (unit_price || 0.0) if subtotal.blank? || subtotal.zero?
  end
end
