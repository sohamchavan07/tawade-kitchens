class Customer < ApplicationRecord
  has_many :orders
  has_many :order_items, through: :orders

  validates :name, presence: true
  validates :phone, presence: true, uniqueness: true

  def add_loyalty_points(amount)
    # 10 points per ₹100
    points = (amount / 100).to_i * 10
    increment!(:loyalty_points, points)
  end
end
