# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      def status
        render json: {
          signed_in: user_signed_in?,
          user: user_signed_in? ? {
            id: current_user.id,
            email: current_user.email,
            name: current_user.respond_to?(:name) ? current_user.name : nil
          } : nil
        }
      end
    end
  end
end
