# frozen_string_literal: true

module Api
  module V1
    class OrdersController < BaseController
      def create
        result = OrderCreator.new(order_params).call

        if result[:success]
          render json: serialize_order_summary(result[:order]), status: :created
        else
          render json: { error: "Order creation failed", details: result[:errors] }, status: :unprocessable_entity
        end
      end

      def show
        order = Order.includes(order_items: :product).find_by(order_number: params[:order_number])

        if order
          render json: serialize_order_detail(order)
        else
          render json: { error: "Order not found" }, status: :not_found
        end
      end

      private

      def order_params
        params.require(:order).permit(
          :customer_name,
          :customer_phone,
          :pickup_date,
          :pickup_time,
          :payment_method,
          :payment_reference,
          :notes,
          items: [ :product_id, :productId, :quantity ]
        )
      end

      def serialize_order_summary(order)
        pickup_address = Rails.application.config.pickup_schedule&.dig(:address)
        operating_hours = Rails.application.config.pickup_schedule&.dig(:operating_hours, :display)

        {
          order_number: order.order_number,
          status: order.status,
          payment_method: order.payment_method,
          payment_status: order.payment_status,
          pickup_date: order.pickup_date&.iso8601,
          pickup_time: order.pickup_time,
          customer_name: order.customer_name,
          total_amount: order.total_amount.to_f,
          notes: order.notes,
          pickup_address: pickup_address,
          operating_hours: operating_hours,
          items: order.order_items.map do |item|
            {
              id: item.id,
              product_id: item.product_id,
              name: item.item_name,
              unit_price: item.unit_price.to_f,
              quantity: item.quantity,
              subtotal: item.subtotal.to_f
            }
          end,
          created_at: order.created_at
        }
      end

      def serialize_order_detail(order)
        serialize_order_summary(order)
      end
    end
  end
end
