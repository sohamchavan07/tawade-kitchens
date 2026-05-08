class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def fallback_index_html
    render file: Rails.public_path.join("index.html"), layout: false
  end
end
