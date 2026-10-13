class AddIngredientsAndSpiceLevelToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :ingredients, :text unless column_exists?(:products, :ingredients)
    add_column :products, :spice_level, :string, default: "mild" unless column_exists?(:products, :spice_level)
  end
end
