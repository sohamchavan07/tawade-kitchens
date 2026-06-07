class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0
      t.string :status, default: 'pending'
      t.string :razorpay_order_id
      t.string :razorpay_payment_id

      t.timestamps
    end
  end
end
