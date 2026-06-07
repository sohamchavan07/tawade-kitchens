ActiveAdmin.register Customer do
  permit_params :name, :phone, :email, :address, :loyalty_points

  index do
    selectable_column
    id_column
    column :name
    column :phone
    column :email
    column :loyalty_points
    actions
  end

  filter :name
  filter :phone
  filter :email
  filter :loyalty_points
end
