# frozen_string_literal: true

class MenuAssistantService
  attr_reader :query

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return empty_query_response if query.blank?

    # Step 1: Rule-Based Engine First (Fast, cheap, deterministic)
    rule_match = match_rules(query.downcase)
    return rule_match if rule_match.present?

    # Step 2: LLM Second for natural language conversation & combinations
    if LlmClient.available?
      llm_match = query_llm
      return llm_match if llm_match.present?
    end

    # Step 3: Friendly fallback catalog summary
    fallback_response
  end

  private

  def lunch_products_for_display(products)
    products.reject { |product| product.name.to_s.match?(/thali|combo/i) }
  end

  def empty_query_response
    {
      reply: "नमस्कार! मी Tawade Kitchen मेनू सहाय्यक आहे. आपण पदार्थांचे स्वाद (तिखट/गोड), बजेट, शाकाहारी पर्याय किंवा किती लोकांसाठी ऑर्डर करायची ते विचारू शकता!",
      products: [],
      source: "rule"
    }
  end

  def match_rules(q)
    available_products = Product.available.to_a

    # Rule 1: Spicy inquiry ("what is spicy", "spicy snacks", "tikhat", "spiciest")
    if q.match?(/\b(spicy|spice|spiciness|tikhat|hot|तिखट)\b/i)
      spicy_items = available_products.select do |p|
        p.spice_level.to_s.downcase.in?(%w[spicy medium]) ||
          p.name.downcase.in?(%w[bakarvadi sev chakli chivda])
      end

      items_desc = spicy_items.map { |p| "#{p.name} (₹#{format('%.2f', p.price)} #{p.unit} - #{p.spice_level&.capitalize || 'Medium'} spicy)" }.join(", ")

      return {
        reply: "Here are our authentic spicy and spiced snacks prepared with traditional Kolhapuri masalas:\n• #{items_desc}.\nBakarvadi and Sev have the most prominent spicy kick!",
        products: spicy_items.map(&:as_catalog_json),
        source: "rule"
      }
    end

    # Rule 2: Vegetarian inquiry ("vegetarian", "veg options", "shakahari", "pure veg", "non veg")
    if q.match?(/\b(vegetarian|veg|shakahari|शाकाहारी|non-?veg)\b/i)
      veg_items = available_products.select(&:vegetarian)
      is_100_percent = veg_items.count == available_products.count

      reply = if is_100_percent
                "Yes! 100% of our kitchen products are purely vegetarian (शुद्ध शाकाहारी). All our sweets and snacks are prepared using pure cow ghee and traditional recipes with no non-vegetarian ingredients."
      else
                "We have #{veg_items.count} authentic vegetarian items available today including #{veg_items.map(&:name).first(4).join(', ')}."
      end

      return {
        reply: reply,
        products: veg_items.map(&:as_catalog_json),
        source: "rule"
      }
    end

    # Rule 3: Price threshold / Budget ("under 150", "under 400", "below ₹500", "cheap", "budget")
    price_match = q.match(/(?:under|below|less than|within|upto|sub)\s*(?:rs\.?|inr|₹)?\s*(\d+)/i) ||
                  q.match(/(?:rs\.?|inr|₹)\s*(\d+)\s*(?:under|below|or less)/i)

    if price_match
      budget = price_match[1].to_f
      budget_items = available_products.select { |p| p.price <= budget }.sort_by(&:price)

      if budget_items.any?
        return {
          reply: "Here are our items priced under ₹#{budget.to_i}:\n" +
                 budget_items.map { |p| "• #{p.name} - ₹#{format('%.2f', p.price)} #{p.unit}" }.join("\n"),
          products: budget_items.map(&:as_catalog_json),
          source: "rule"
        }
      else
        min_price = available_products.map(&:price).min
        return {
          reply: "We currently don't have items strictly under ₹#{budget.to_i}. Our most affordable item is #{available_products.find { |p| p.price == min_price }&.name} at ₹#{format('%.2f', min_price)}.",
          products: available_products.select { |p| p.price == min_price }.map(&:as_catalog_json),
          source: "rule"
        }
      end
    end

    # Rule 4: Group / People size ("for 3 people", "for 4 people", "family of 5")
    people_match = q.match(/\b(?:for|serves?)\s*(\d+)\s*(?:people|persons?|guests?|members?|family)?\b/i) ||
                   q.match(/\b(\d+)\s*(?:people|persons?|guests?)\b/i)

    if people_match
      count = people_match[1].to_i
      recommended = suggest_combo_for_people(count, available_products)
      total_cost = recommended.sum(&:price)

      return {
        reply: "For #{count} people, we recommend a balanced Kolhapuri festive assortment with both savouries and sweets:\n" +
               recommended.map { |p| "• #{p.name} (₹#{format('%.2f', p.price)})" }.join("\n") +
               "\nTotal for this combination: ₹#{format('%.2f', total_cost)}. It offers crispy savouries for tea and traditional melt-in-mouth sweets!",
        products: recommended.map(&:as_catalog_json),
        source: "rule"
      }
    end

    # Rule 5: Sweet cravings / Sweets specific
    if q.match?(/\b(sweet|sweets|mithai|ladoo|laddu|sugar|dessert|गोड)\b/i)
      sweets = available_products.select { |p| p.category.to_s.downcase == "sweets" || p.name.downcase.include?("ladoo") }
      return {
        reply: "Here are our signature homemade sweets prepared with pure cow ghee:\n" +
               sweets.map { |p| "• #{p.name} - ₹#{format('%.2f', p.price)} #{p.unit} (#{p.description})" }.join("\n"),
        products: sweets.map(&:as_catalog_json),
        source: "rule"
      }
    end

    # Rule 5b: Lunch inquiry ("lunch", "thali", "meal", "जेवण", "थाली")
    if q.match?(/\b(lunch|lunches|thali|meal|meals|जेवण|थाली|खाना)\b/i)
      lunch = lunch_products_for_display(available_products.select { |p| p.category.to_s.downcase == "lunch" })
      if lunch.any?
        return {
          reply: "We serve fresh homemade Kolhapuri lunch daily for pickup:\n" +
                 lunch.map { |p| "• #{p.name} - ₹#{format('%.2f', p.price)} #{p.unit} (#{p.description})" }.join("\n") +
                 "\nOur Lunch Thali comes with 2 chapati, bhaji, dal and rice. All lunch items are vegetarian and made fresh each morning.",
          products: lunch.map(&:as_catalog_json),
          source: "rule"
        }
      end
    end

    # Rule 6: Pickup timing / operating hours / location
    if q.match?(/\b(pickup|timing|time|open|hours|closing|address|location|where)\b/i)
      hours = Rails.application.config.pickup_schedule&.dig(:operating_hours, :display) || "9:00 AM - 8:00 PM IST"
      address = Rails.application.config.pickup_schedule&.dig(:address) || "Plot no 7, Mukt Sainik Vasahat, Kolhapur"
      return {
        reply: "Tawade Kitchen operates strictly for pickup orders!\n⏰ Operating Hours: #{hours} (Monday - Sunday)\n📍 Pickup Address: #{address}\nOrders are packed fresh for your selected pickup slot.",
        products: available_products.first(3).map(&:as_catalog_json),
        source: "rule"
      }
    end

    nil
  end

  def suggest_combo_for_people(people_count, products)
    sweets = products.select { |p| p.category.to_s.downcase == "sweets" }
    snacks = products.select { |p| p.category.to_s.downcase == "snacks" }
    lunch = lunch_products_for_display(products.select { |p| p.category.to_s.downcase == "lunch" })

    combo = []
    if people_count <= 2
      combo << (snacks.find { |p| p.name.downcase.include?("chakli") } || snacks.first)
      combo << (sweets.find { |p| p.name.downcase.include?("besan") } || sweets.first)
    elsif people_count <= 4
      combo << (snacks.find { |p| p.name.downcase.include?("chakli") } || snacks[0])
      combo << (snacks.find { |p| p.name.downcase.include?("chivda") } || snacks[1])
      combo << (sweets.find { |p| p.name.downcase.include?("besan") } || sweets[0])
    else
      combo << (snacks.find { |p| p.name.downcase.include?("chakli") } || snacks[0])
      combo << (snacks.find { |p| p.name.downcase.include?("bakarvadi") } || snacks[1])
      combo << (snacks.find { |p| p.name.downcase.include?("chivda") } || snacks[2])
      combo << (sweets.find { |p| p.name.downcase.include?("besan") } || sweets[0])
      combo << (sweets.find { |p| p.name.downcase.include?("rava") } || sweets[1])
    end

    # Add a lunch thali for groups that need a full meal alongside the snacks
    if people_count >= 3
      thali = lunch.find { |p| p.name.downcase.include?("thali") } || lunch.first
      combo << thali
    end

    combo.compact.uniq
  end

  def query_llm
    catalog = Product.available.map(&:as_catalog_json)
    system_prompt = <<~PROMPT
      You are the official AI Menu Assistant for Tawade Kitchen, an authentic homemade Kolhapuri sweets & snacks pickup store.
      Address: #{Rails.application.config.pickup_schedule&.dig(:address) || 'Plot no 7, Mukt Sainik Vasahat, Kolhapur'}
      Operating Hours: #{Rails.application.config.pickup_schedule&.dig(:operating_hours, :display) || '9:00 AM - 8:00 PM IST'} (Pickup-only store).

      Here is our complete live product catalog in JSON:
      #{catalog.to_json}

      Guidelines:
      - Answer the customer's question concisely, warm, and helpful.
      - Mention authentic flavours, ghee, Kolhapuri authenticity, and ingredients when relevant.
      - Never fabricate products not present in the catalog.
      - If recommending items, provide their exact IDs in a bracketed JSON block at the end in this format:
        RECOMMENDED_IDS: [id1, id2]
    PROMPT

    raw_response = LlmClient.call(prompt: query, system_prompt: system_prompt)
    return nil if raw_response.blank?

    # Extract recommended IDs if present
    recommended_ids = []
    clean_reply = raw_response.gsub(/RECOMMENDED_IDS:\s*\[([\d,\s]*)\]/i) do
      id_strs = Regexp.last_match(1).split(",").map(&:strip).reject(&:blank?)
      recommended_ids = id_strs.map(&:to_i)
      ""
    end.strip

    products = if recommended_ids.any?
                 Product.where(id: recommended_ids).map(&:as_catalog_json)
    else
                 []
    end

    {
      reply: clean_reply,
      products: products,
      source: "llm"
    }
  end

  def fallback_response
    products = Product.available.limit(4).to_a
    {
      reply: "We have authentic Kolhapuri snacks and sweets freshly prepared daily for pickup! You can ask me about spicy items, prices, vegetarian treats, or personalized recommendations.",
      products: products.map(&:as_catalog_json),
      source: "rule"
    }
  end
end
