class Order < ApplicationRecord
  belongs_to :customer
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  accepts_nested_attributes_for :order_items

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  after_create :deduct_stock
  after_create :update_loyalty_points
  after_create :send_whatsapp_confirmation

  private

  def send_whatsapp_confirmation
    WhatsappConfirmationJob.perform_later(self.id)
  end

  def deduct_stock
    order_items.each do |item|
      item.product.decrement!(:stock_quantity, item.quantity)
    end
  end

  def update_loyalty_points
    customer.add_loyalty_points(total_amount)
  end
end
