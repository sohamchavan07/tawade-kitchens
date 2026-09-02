# frozen_string_literal: true

Rails.application.configure do
  config.pickup_schedule = {
    business_name: "Tawade Kitchen",
    address: "Plot no 7, Mukt Sainik Vasahat, Opp Mukt Sainik Udyan, PO: Gur Market Yard, Kolhapur, Maharashtra 416005",
    maps_url: "https://maps.app.goo.gl/fE2oV7vcLptDP2hr6",
    whatsapp_number: "9860002903",
    timezone: "Asia/Kolkata",
    operating_hours: {
      start_time: "09:00",
      end_time: "20:00"
    },
    slot_interval_minutes: 30,
    min_advance_minutes: 30,
    days_open: %w[monday tuesday wednesday thursday friday saturday sunday],
    upi_id: ENV.fetch("TAWADE_UPI_ID", "tawadekitchen@upi")
  }
end
