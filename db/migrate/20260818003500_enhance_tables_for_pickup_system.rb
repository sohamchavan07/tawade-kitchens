class EnhanceTablesForPickupSystem < ActiveRecord::Migration[8.0]
  def up
    # 1. Enhance products table with availability, preparation time, and vegetarian flag
    add_column :products, :is_available, :boolean, default: true, null: false unless column_exists?(:products, :is_available)
    add_column :products, :preparation_time, :integer, default: 15 unless column_exists?(:products, :preparation_time)
    add_column :products, :vegetarian, :boolean, default: true, null: false unless column_exists?(:products, :vegetarian)

    # 2. Enhance orders table with pickup and payment fields
    add_column :orders, :order_number, :string unless column_exists?(:orders, :order_number)
    add_column :orders, :customer_name, :string unless column_exists?(:orders, :customer_name)
    add_column :orders, :customer_phone, :string unless column_exists?(:orders, :customer_phone)
    add_column :orders, :pickup_date, :date unless column_exists?(:orders, :pickup_date)
    add_column :orders, :pickup_time, :string unless column_exists?(:orders, :pickup_time)
    add_column :orders, :payment_method, :string, default: "pay_at_pickup", null: false unless column_exists?(:orders, :payment_method)
    add_column :orders, :payment_status, :string, default: "pending", null: false unless column_exists?(:orders, :payment_status)
    add_column :orders, :payment_reference, :string unless column_exists?(:orders, :payment_reference)
    add_column :orders, :notes, :text unless column_exists?(:orders, :notes)

    # Make customer_id optional on orders so direct pickup orders can be placed
    change_column_null :orders, :customer_id, true if column_exists?(:orders, :customer_id)

    # Add unique index on order_number
    add_index :orders, :order_number, unique: true unless index_exists?(:orders, :order_number)

    # Backfill order_number for any existing orders
    Order.reset_column_information if defined?(Order)
    if defined?(Order)
      Order.where(order_number: nil).find_each do |order|
        date_part = order.created_at ? order.created_at.in_time_zone("Asia/Kolkata").strftime("%Y%m%d") : Time.current.in_time_zone("Asia/Kolkata").strftime("%Y%m%d")
        random_suffix = SecureRandom.alphanumeric(4).upcase
        order.update_columns(order_number: "TK-#{date_part}-#{random_suffix}")
      end
    end

    # 3. Enhance order_items table with item_name and subtotal
    add_column :order_items, :item_name, :string unless column_exists?(:order_items, :item_name)
    add_column :order_items, :subtotal, :decimal, precision: 10, scale: 2, default: 0.0, null: false unless column_exists?(:order_items, :subtotal)

    # Backfill item_name and subtotal for existing order_items
    OrderItem.reset_column_information if defined?(OrderItem)
    if defined?(OrderItem)
      OrderItem.where(subtotal: 0.0).find_each do |item|
        calculated_subtotal = (item.quantity || 1) * (item.unit_price || 0.0)
        product_name = item.product&.name || "Item"
        item.update_columns(item_name: product_name, subtotal: calculated_subtotal)
      end
    end
  end

  def down
    remove_index :orders, :order_number if index_exists?(:orders, :order_number)

    remove_column :order_items, :subtotal if column_exists?(:order_items, :subtotal)
    remove_column :order_items, :item_name if column_exists?(:order_items, :item_name)

    remove_column :orders, :notes if column_exists?(:orders, :notes)
    remove_column :orders, :payment_reference if column_exists?(:orders, :payment_reference)
    remove_column :orders, :payment_status if column_exists?(:orders, :payment_status)
    remove_column :orders, :payment_method if column_exists?(:orders, :payment_method)
    remove_column :orders, :pickup_time if column_exists?(:orders, :pickup_time)
    remove_column :orders, :pickup_date if column_exists?(:orders, :pickup_date)
    remove_column :orders, :customer_phone if column_exists?(:orders, :customer_phone)
    remove_column :orders, :customer_name if column_exists?(:orders, :customer_name)
    remove_column :orders, :order_number if column_exists?(:orders, :order_number)

    remove_column :products, :vegetarian if column_exists?(:products, :vegetarian)
    remove_column :products, :preparation_time if column_exists?(:products, :preparation_time)
    remove_column :products, :is_available if column_exists?(:products, :is_available)
  end
end
