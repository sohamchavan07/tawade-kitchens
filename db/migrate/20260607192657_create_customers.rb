class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :phone
      t.string :email
      t.text :address
      t.integer :loyalty_points, default: 0

      t.timestamps
    end
    add_index :customers, :phone
  end
end
