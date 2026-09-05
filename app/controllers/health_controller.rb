class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :ping

  def ping
    render plain: "OK"
  end
end
