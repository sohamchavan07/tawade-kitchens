ActiveAdmin.register Order do
  permit_params :customer_id, :total_amount, :status, :razorpay_order_id, :razorpay_payment_id

  index do
    selectable_column
    id_column
    column :customer
    column :total_amount do |order|
      number_to_currency(order.total_amount, unit: "₹")
    end
    column :status do |order|
      status_tag order.status
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :customer
      row :total_amount
      row :status
      row :razorpay_order_id
      row :razorpay_payment_id
      row :created_at
    end

    panel "Order Items" do
      table_for order.order_items do
        column :product
        column :quantity
        column :unit_price
        column "Total" do |item|
          number_to_currency(item.quantity * item.unit_price, unit: "₹")
        end
      end
    end
  end

  filter :customer
  filter :status, as: :select, collection: %w[pending confirmed delivered cancelled]
  filter :total_amount
  filter :created_at
end
