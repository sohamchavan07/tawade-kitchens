class AddUnitToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :unit, :string, default: "per kg" unless column_exists?(:products, :unit)
  end
end
