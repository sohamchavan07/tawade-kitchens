# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class LlmClient
  DEFAULT_TIMEOUT = 12

  def self.available?
    gemini_key.present? || openai_key.present?
  end

  def self.call(prompt:, system_prompt: nil)
    new.call(prompt: prompt, system_prompt: system_prompt)
  end

  def call(prompt:, system_prompt: nil)
    if self.class.gemini_key.present?
      call_gemini(prompt, system_prompt)
    elsif self.class.openai_key.present?
      call_openai(prompt, system_prompt)
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.warn("LLM API call failed: #{e.message}")
    nil
  end

  def self.gemini_key
    ENV["GEMINI_API_KEY"].presence || ENV["GOOGLE_API_KEY"].presence
  end

  def self.openai_key
    ENV["OPENAI_API_KEY"].presence
  end

  private

  def call_gemini(prompt, system_prompt)
    key = self.class.gemini_key
    # Use gemini-1.5-flash or gemini-2.5-flash
    model = ENV.fetch("GEMINI_MODEL", "gemini-1.5-flash")
    url = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{key}")

    full_system = system_prompt.to_s.strip
    body = {
      contents: [
        {
          role: "user",
          parts: [ { text: full_system.present? ? "#{full_system}\n\nCustomer question: #{prompt}" : prompt } ]
        }
      ],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 600
      }
    }

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.open_timeout = DEFAULT_TIMEOUT
    http.read_timeout = DEFAULT_TIMEOUT

    req = Net::HTTP::Post.new(url.request_uri, { "Content-Type" => "application/json" })
    req.body = body.to_json

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body)
    parsed.dig("candidates", 0, "content", "parts", 0, "text")
  end

  def call_openai(prompt, system_prompt)
    key = self.class.openai_key
    url = URI("https://api.openai.com/v1/chat/completions")

    messages = []
    messages << { role: "system", content: system_prompt } if system_prompt.present?
    messages << { role: "user", content: prompt }

    body = {
      model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
      messages: messages,
      temperature: 0.2,
      max_tokens: 600
    }

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.open_timeout = DEFAULT_TIMEOUT
    http.read_timeout = DEFAULT_TIMEOUT

    req = Net::HTTP::Post.new(url.request_uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{key}"
    })
    req.body = body.to_json

    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body)
    parsed.dig("choices", 0, "message", "content")
  end
end
