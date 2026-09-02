# frozen_string_literal: true

ActiveAdmin.register Product do
  menu priority: 1, label: "Menu Items (मेनू पदार्थ)"

  permit_params :name, :description, :price, :stock_quantity, :category, :image_url, :preparation_time, :vegetarian, :is_available

  config.sort_order = "name_asc"

  scope :all, default: true
  scope("Available (उपलब्ध)") { |prods| prods.where(is_available: true) }
  scope("Unavailable (अनुपलब्ध)") { |prods| prods.where(is_available: false) }
  scope("Sweets (गोड पदार्थ)") { |prods| prods.where(category: "Sweets") }
  scope("Snacks (फराळ)") { |prods| prods.where(category: "Snacks") }

  member_action :toggle_availability, method: :put do
    resource.update!(is_available: !resource.is_available)
    status_label = resource.is_available? ? "Available" : "Unavailable"
    redirect_to admin_products_path, notice: "'#{resource.name}' is now marked as #{status_label}."
  rescue StandardError => e
    redirect_to admin_products_path, alert: "Could not toggle availability: #{e.message}"
  end

  action_item :toggle, only: :show do
    btn_text = resource.is_available? ? "Mark Unavailable" : "Mark Available"
    link_to btn_text, toggle_availability_admin_product_path(resource), method: :put, class: "button"
  end

  index do
    selectable_column
    id_column
    column :name
    column :category
    column :price do |product|
      number_to_currency(product.price, unit: "₹")
    end
    column :stock_quantity
    column "Prep (Min)", :preparation_time
    column :vegetarian do |product|
      product.vegetarian? ? status_tag("Veg", class: "green") : status_tag("Non-Veg", class: "red")
    end
    column :is_available do |product|
      product.is_available? ? status_tag("Available", class: "ok") : status_tag("Out of Stock", class: "red")
    end
    actions do |product|
      btn_text = product.is_available? ? "Mark Out of Stock" : "Mark Available"
      link_to btn_text, toggle_availability_admin_product_path(product), method: :put, class: "member_link"
    end
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :category
      row :price do |product|
        number_to_currency(product.price, unit: "₹")
      end
      row :stock_quantity
      row :preparation_time do |product|
        "#{product.preparation_time} minutes"
      end
      row :vegetarian do |product|
        status_tag(product.vegetarian? ? "Veg" : "Non-Veg")
      end
      row :is_available do |product|
        status_tag(product.is_available? ? "Available" : "Out of Stock")
      end
      row :image_url
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Menu Item Details" do
      f.input :name
      f.input :description
      f.input :category, as: :select, collection: %w[Sweets Snacks Beverages Bakery Other]
      f.input :price, min: 0, step: 0.5
      f.input :stock_quantity, min: 0
      f.input :preparation_time, label: "Preparation Time (minutes)", min: 0
      f.input :vegetarian, as: :boolean
      f.input :is_available, as: :boolean, label: "Is Available for Orders"
      f.input :image_url, placeholder: "/assets/filename.jpg"
    end
    f.actions
  end

  controller do
    def destroy
      destroy! do |success, failure|
        failure.html do
          flash[:error] = "Cannot delete '#{resource.name}' because it is referenced in past customer orders. Please mark it as 'Out of Stock' instead."
          redirect_to admin_products_path
        end
      end
    end
  end

  filter :name
  filter :category, as: :select, collection: %w[Sweets Snacks Beverages Bakery Other]
  filter :price
  filter :is_available, as: :select
  filter :vegetarian, as: :select
end
