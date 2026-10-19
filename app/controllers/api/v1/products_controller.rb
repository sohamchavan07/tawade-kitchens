# frozen_string_literal: true

module Api
  module V1
    class ProductsController < BaseController
      def index
        products = Product.available
        products = products.by_category(params[:category]) if params[:category].present?

        render json: products.map { |product| serialize_product(product) }
      end

      def show
        product = Product.find(params[:id])
        render json: serialize_product(product)
      end

      private

      def serialize_product(product)
        {
          id: product.id,
          name: product.name,
          description: product.description,
          price: product.price.to_f,
          unit: product.unit,
          image_url: product.image_url,
          category: product.category,
          is_available: product.is_available,
          preparation_time: product.preparation_time,
          vegetarian: product.vegetarian,
          created_at: product.created_at,
          updated_at: product.updated_at
        }
      end
    end
  end
end
