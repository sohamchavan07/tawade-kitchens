# frozen_string_literal: true

class Order < ApplicationRecord
  class InvalidStatusTransitionError < StandardError; end

  STATUSES = %w[pending confirmed preparing ready_for_pickup collected cancelled].freeze
  NEW_PAYMENT_METHODS = %w[pay_at_pickup upi_after_confirmation].freeze
  LEGACY_PAYMENT_METHODS = %w[upi].freeze
  PAYMENT_METHODS = (NEW_PAYMENT_METHODS + LEGACY_PAYMENT_METHODS).freeze
  PAYMENT_STATUSES = %w[pending submitted verified failed refunded].freeze

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[confirmed cancelled],
    "confirmed" => %w[preparing cancelled],
    "preparing" => %w[ready_for_pickup cancelled],
    "ready_for_pickup" => %w[collected cancelled],
    "collected" => [],
    "cancelled" => []
  }.freeze

  ALLOWED_PAYMENT_TRANSITIONS = {
    "pending" => %w[submitted verified failed],
    "submitted" => %w[verified failed],
    "verified" => %w[refunded],
    "failed" => %w[submitted verified],
    "refunded" => []
  }.freeze

  belongs_to :customer, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  accepts_nested_attributes_for :order_items

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_status, presence: true, inclusion: { in: PAYMENT_STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_blank: true
  validates :order_number, uniqueness: true, allow_nil: true

  validate :pickup_date_cannot_be_in_past, on: :create
  validate :enforce_valid_status_transition, on: :update, if: :will_save_change_to_status?
  validate :enforce_valid_payment_status_transition, on: :update, if: :will_save_change_to_payment_status?

  before_validation :ensure_order_number, on: :create
  before_validation :set_default_statuses, on: :create

  after_create :deduct_stock
  after_create :update_loyalty_points

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id order_number status payment_status payment_method payment_reference
      customer_name customer_phone pickup_date pickup_time total_amount notes
      created_at updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[customer order_items products]
  end

  def generate_order_number
    loop do
      date_part = Time.current.in_time_zone("Asia/Kolkata").strftime("%Y%m%d")
      random_suffix = SecureRandom.alphanumeric(4).upcase
      candidate = "TK-#{date_part}-#{random_suffix}"
      self.order_number = candidate
      break candidate unless Order.exists?(order_number: candidate)
    end
  end

  def can_transition_to_status?(new_status)
    return true if status == new_status.to_s

    ALLOWED_STATUS_TRANSITIONS[status]&.include?(new_status.to_s) || false
  end

  def transition_to_status!(new_status)
    unless can_transition_to_status?(new_status)
      raise InvalidStatusTransitionError, "Cannot transition order status from '#{status}' to '#{new_status}'"
    end

    update!(status: new_status)
  end

  def can_transition_to_payment_status?(new_payment_status)
    return true if payment_status == new_payment_status.to_s

    ALLOWED_PAYMENT_TRANSITIONS[payment_status]&.include?(new_payment_status.to_s) || false
  end

  def transition_to_payment_status!(new_payment_status)
    unless can_transition_to_payment_status?(new_payment_status)
      raise InvalidStatusTransitionError, "Cannot transition payment status from '#{payment_status}' to '#{new_payment_status}'"
    end

    update!(payment_status: new_payment_status)
  end

  def record_payment_reference!(utr)
    if status == "pending"
      raise InvalidStatusTransitionError, "Cannot record payment reference before order is confirmed by kitchen"
    end
    if status == "cancelled"
      raise InvalidStatusTransitionError, "Cannot record payment reference for a cancelled order"
    end

    clean_utr = utr.to_s.strip
    if clean_utr.blank?
      raise ArgumentError, "Payment reference (UTR) cannot be blank"
    elsif clean_utr.length > 50
      raise ArgumentError, "Payment reference (UTR) cannot exceed 50 characters"
    elsif clean_utr.length < 4
      raise ArgumentError, "Payment reference (UTR) must be at least 4 characters"
    end

    update!(payment_reference: clean_utr, payment_status: "submitted")
  end

  private

  def ensure_order_number
    self.order_number ||= generate_order_number
  end

  def set_default_statuses
    self.status ||= "pending"
    self.payment_status ||= "pending"
    self.payment_method ||= "pay_at_pickup"
  end

  def pickup_date_cannot_be_in_past
    return if pickup_date.blank?

    today = Time.current.in_time_zone("Asia/Kolkata").to_date
    if pickup_date < today
      errors.add(:pickup_date, "cannot be in the past")
    end
  end

  def enforce_valid_status_transition
    old_status = status_was
    new_status = status

    unless ALLOWED_STATUS_TRANSITIONS[old_status]&.include?(new_status)
      errors.add(:status, "cannot transition from #{old_status} to #{new_status}")
    end
  end

  def enforce_valid_payment_status_transition
    old_payment_status = payment_status_was
    new_payment_status = payment_status

    unless ALLOWED_PAYMENT_TRANSITIONS[old_payment_status]&.include?(new_payment_status)
      errors.add(:payment_status, "cannot transition from #{old_payment_status} to #{new_payment_status}")
    end
  end

  def deduct_stock
    order_items.each do |item|
      item.product&.decrement!(:stock_quantity, item.quantity)
    end
  end

  def update_loyalty_points
    customer&.add_loyalty_points(total_amount)
  end
end
