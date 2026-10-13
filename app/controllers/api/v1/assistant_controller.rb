# frozen_string_literal: true

module Api
  module V1
    class AssistantController < BaseController
      def chat
        query = params[:message].presence || params[:query].presence || params[:text].presence

        if query.blank?
          render json: { error: "Message query is required" }, status: :unprocessable_entity
          return
        end

        result = MenuAssistantService.new(query).call

        render json: {
          reply: result[:reply],
          products: result[:products],
          source: result[:source]
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error("Assistant chat error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        render json: {
          reply: "I am having a brief moment processing your request. Please explore our menu below or ask again!",
          products: Product.available.limit(3).map(&:as_catalog_json),
          source: "error"
        }, status: :ok
      end
    end
  end
end
