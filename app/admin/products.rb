ActiveAdmin.register Product do
  permit_params :name, :description, :price, :stock_quantity, :category, :image_url

  index do
    selectable_column
    id_column
    column :name
    column :category
    column :price do |product|
      number_to_currency(product.price, unit: "₹")
    end
    column :stock_quantity
    actions
  end

  filter :name
  filter :category
  filter :price
  filter :stock_quantity
end
