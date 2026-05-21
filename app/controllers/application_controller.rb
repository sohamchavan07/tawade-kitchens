class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def fallback_index_html
    index_file = Rails.public_path.join("index.html")
    if File.exist?(index_file)
      render file: index_file, layout: false, content_type: "text/html"
    else
      render plain: "Frontend build missing. Please check your build scripts.", status: :not_found
    end
  end
end
