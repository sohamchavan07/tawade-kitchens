class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.text :description
      t.decimal :price, precision: 10, scale: 2, default: 0.0
      t.integer :stock_quantity, default: 0
      t.string :category
      t.string :image_url

      t.timestamps
    end
  end
end
