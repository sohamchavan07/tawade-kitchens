module Api
  class OrdersController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      customer = find_or_create_customer

      Order.transaction do
        @order = Order.new(order_params.merge(customer: customer))

        if @order.save
          # Razorpay order creation (optional, but requested)
          # razorpay_order = Razorpay::Order.create(amount: (@order.total_amount * 100).to_i, currency: 'INR', receipt: "order_#{@order.id}")
          # @order.update(razorpay_order_id: razorpay_order.id)

          # In a real app, we'd trigger the WhatsApp job here
          # WhatsappConfirmationJob.perform_later(@order.id)

          render json: { order: @order, customer: customer }, status: :created
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    private

    def find_or_create_customer
      Customer.find_or_create_by!(phone: params[:customer][:phone]) do |c|
        c.name = params[:customer][:name]
        c.email = params[:customer][:email]
        c.address = params[:customer][:address]
      end
    end

    def order_params
      params.require(:order).permit(:total_amount, order_items_attributes: [ :product_id, :quantity, :unit_price ])
    end
  end
end
