# Multi-Intent Detection Service
# Birden fazla mesajı analiz edip intent'leri tespit eder
# Confidence score ile ürün araması güvenilirliğini değerlendirir
#
# Kullanım:
#   service = Saturn::MultiIntentDetectionService.new(assistant: assistant, messages: messages)
#   result = service.detect
#   
#   # Intent'e göre aksiyon al:
#   if result[:intents].include?(:clarification_needed)
#     question = service.build_clarification_question(result)
#   elsif result[:intents].include?(:product_query) && result[:confidence] >= 70
#     search_products(result[:product_keywords])
#   end

class Saturn::MultiIntentDetectionService
  INTENT_TYPES = {
    greeting: 'Selamlama',
    farewell: 'Vedalaşma',
    thanks: 'Teşekkür',
    product_query: 'Ürün sorgusu',
    order_query: 'Sipariş sorgusu',
    general_question: 'Genel soru',
    complaint: 'Şikayet',
    human_request: 'Müşteri temsilcisi talebi',
    confirmation: 'Onay/Red',
    clarification_needed: 'Netleştirme gerekli',
    other: 'Diğer'
  }.freeze

  # Confidence eşikleri
  CONFIDENCE_HIGH = 70      # Direkt ürün ara
  CONFIDENCE_MEDIUM = 40    # Netleştirme sorusu sor

  # Ürün kategorileri
  PRODUCT_CATEGORIES = %w[
    kolye bileklik yüzük küpe halhal set takı aksesuar zincir madalyon charm
    bilezik pendant broş toka saç yaka rozet iğne tespih tesbih
  ].freeze

  # Ürün özellikleri
  PRODUCT_ATTRIBUTES = %w[
    taşlı altın gümüş çelik inci pırlanta zirkon baget dorika kristal
    kaplama ayar elmas yakut zümrüt safir ametist akik sedef
  ].freeze

  # Renkler
  PRODUCT_COLORS = %w[
    siyah beyaz mor fuşya pembe mavi yeşil kırmızı sarı turuncu
    gold silver rose gri lacivert turkuaz bordo bej krem kahve
  ].freeze

  def initialize(assistant:, messages:)
    @assistant = assistant
    @messages = Array(messages).map(&:to_s).reject(&:blank?)
  end

  # Ana metod - intent tespiti yapar, sonucu döndürür
  # Sonuç: { intents: [...], confidence: N, product_keywords: [...], ... }
  def detect
    return empty_result if @messages.empty?

    combined_message = @messages.join(' ')

    # Önce confidence score hesapla
    confidence_result = calculate_product_confidence(combined_message)

    # Tek mesaj ve basit pattern ise hızlı kontrol
    if @messages.size == 1 && simple_intent?(@messages.first) && confidence_result[:confidence] < CONFIDENCE_MEDIUM
      return quick_detect(@messages.first)
    end

    # Ürün kelimesi içeriyorsa confidence'a göre değerlendir
    if confidence_result[:has_product_words]
      return build_product_result(combined_message, confidence_result)
    end

    # LLM ile detaylı analiz
    llm_detect
  end

  # Netleştirme sorusu oluştur - detect sonucunu parametre olarak alır
  def build_clarification_question(result)
    confidence_details = result[:confidence_details] || {}
    keywords = result[:product_keywords] || []

    if confidence_details[:has_color] && !confidence_details[:has_category]
      color = confidence_details[:color_matches]&.first || keywords.first
      "#{color&.capitalize} renkli hangi tür ürün arıyorsunuz? (kolye, bileklik, yüzük, küpe, halhal)"
    elsif confidence_details[:has_attribute] && !confidence_details[:has_category]
      attr = confidence_details[:attribute_matches]&.first || keywords.first
      "#{attr&.capitalize} hangi tür ürün arıyorsunuz? (kolye, bileklik, yüzük, küpe, halhal)"
    elsif confidence_details[:has_attribute] && confidence_details[:has_color] && !confidence_details[:has_category]
      color = confidence_details[:color_matches]&.first
      attr = confidence_details[:attribute_matches]&.first
      "#{color&.capitalize} #{attr} hangi tür ürün arıyorsunuz? (kolye, bileklik, yüzük, küpe, halhal)"
    elsif confidence_details[:has_category] && !confidence_details[:has_attribute] && !confidence_details[:has_color]
      category = confidence_details[:category_matches]&.first || keywords.first
      "Nasıl bir #{category} arıyorsunuz? (altın, gümüş, taşlı, inci vb.)"
    elsif keywords.any?
      "\"#{keywords.join(' ')}\" ile ilgili biraz daha detay verebilir misiniz? Hangi tür ürün arıyorsunuz?"
    else
      "Ne tür bir ürün arıyorsunuz? Biraz daha detay verebilir misiniz?"
    end
  end

  private

  def empty_result
    {
      intents: [],
      product_keywords: [],
      combined_message: '',
      confidence: 0,
      confidence_details: {},
      raw_analysis: nil
    }
  end

  def calculate_product_confidence(message)
    clean_message = message.downcase.strip

    category_matches = PRODUCT_CATEGORIES.select { |c| clean_message.include?(c) }
    attribute_matches = PRODUCT_ATTRIBUTES.select { |a| clean_message.include?(a) }
    color_matches = PRODUCT_COLORS.select { |c| clean_message.include?(c) }

    has_category = category_matches.any?
    has_attribute = attribute_matches.any?
    has_color = color_matches.any?

    # Skor: Kategori (50), Özellik (30), Renk (20)
    score = 0
    score += 50 if has_category
    score += 30 if has_attribute
    score += 20 if has_color

    # Sadece renk → max 25
    score = [score, 25].min if has_color && !has_category && !has_attribute

    # Sadece özellik → max 35
    score = [score, 35].min if has_attribute && !has_category && !has_color

    {
      confidence: score,
      has_product_words: has_category || has_attribute || has_color,
      category_matches: category_matches,
      attribute_matches: attribute_matches,
      color_matches: color_matches,
      has_category: has_category,
      has_attribute: has_attribute,
      has_color: has_color
    }
  end

  def build_product_result(message, confidence_result)
    confidence = confidence_result[:confidence]

    keywords = (
      confidence_result[:category_matches] +
      confidence_result[:attribute_matches] +
      confidence_result[:color_matches]
    ).uniq

    # Intent belirle
    intents = if confidence >= CONFIDENCE_HIGH
                Rails.logger.info "[INTENT] HIGH confidence (#{confidence}%) → product_query: #{keywords.inspect}"
                [:product_query]
              elsif confidence >= CONFIDENCE_MEDIUM
                Rails.logger.info "[INTENT] MEDIUM confidence (#{confidence}%) → clarification_needed: #{keywords.inspect}"
                [:clarification_needed]
              else
                Rails.logger.info "[INTENT] LOW confidence (#{confidence}%) → clarification_needed: #{keywords.inspect}"
                [:clarification_needed]
              end

    {
      intents: intents,
      product_keywords: keywords,
      combined_message: message,
      confidence: confidence,
      confidence_details: confidence_result,
      raw_analysis: nil
    }
  end

  def simple_intent?(message)
    clean = message.strip.downcase

    product_words = Regexp.union(PRODUCT_CATEGORIES + PRODUCT_ATTRIBUTES + PRODUCT_COLORS)
    return false if clean.match?(product_words)

    return true if clean.length < 15

    simple_patterns.any? { |pattern| clean.match?(pattern) }
  end

  def simple_patterns
    [
      /\A(merhaba|selam|hey|hi|hello|günaydın|iyi\s*günler)\s*[!.?]*\z/i,
      /\A(teşekkür|sağol|thanks)\s*[!.?]*\z/i,
      /\A(görüşürüz|hoşça\s*kal|bye)\s*[!.?]*\z/i,
      /\A(evet|hayır|tamam|ok|peki)\s*[!.?]*\z/i
    ]
  end

  def quick_detect(message)
    clean = message.strip.downcase
    intents = []

    intents << :greeting if clean.match?(/\A(merhaba|selam|hey|hi|hello|günaydın|iyi\s*günler)/i)
    intents << :farewell if clean.match?(/\A(görüşürüz|hoşça\s*kal|bye|güle\s*güle)/i)
    intents << :thanks if clean.match?(/\A(teşekkür|sağol|thanks)/i)
    intents << :confirmation if clean.match?(/\A(evet|hayır|tamam|ok|peki|olur|olmaz)/i)
    intents << :other if intents.empty?

    {
      intents: intents,
      product_keywords: [],
      combined_message: message,
      confidence: 0,
      confidence_details: {},
      raw_analysis: nil
    }
  end

  def llm_detect
    combined_message = @messages.join("\n")

    begin
      response = call_llm(build_analysis_prompt(combined_message))
      parse_llm_response(response, combined_message)
    rescue StandardError => e
      Rails.logger.error "[INTENT] LLM failed: #{e.message}"
      fallback_detect(combined_message)
    end
  end

  def build_analysis_prompt(message)
    <<~PROMPT
      Müşteri mesajını analiz et. SADECE JSON döndür:
      
      Mesaj: #{message}
      
      Intent türleri: greeting, farewell, thanks, product_query, order_query, general_question, complaint, human_request, confirmation, other
      
      Format:
      {"intents": ["intent1"], "product_keywords": ["keyword1"], "summary": "özet"}
    PROMPT
  end

  def call_llm(prompt)
    client = OpenAI::Client.new(access_token: GlobalConfigService.load('OPENAI_API_KEY', nil))
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.1,
        max_tokens: 200
      }
    )
    response.dig('choices', 0, 'message', 'content')
  end

  def parse_llm_response(response, combined_message)
    return fallback_detect(combined_message) if response.blank?

    json_match = response.match(/\{[\s\S]*\}/)
    return fallback_detect(combined_message) unless json_match

    parsed = JSON.parse(json_match[0])
    intents = (parsed['intents'] || []).map { |i| i.to_s.downcase.to_sym }
    intents = [:other] if intents.empty?

    confidence_result = calculate_product_confidence(combined_message)

    {
      intents: intents,
      product_keywords: parsed['product_keywords'] || [],
      combined_message: combined_message,
      confidence: confidence_result[:confidence],
      confidence_details: confidence_result,
      summary: parsed['summary'],
      raw_analysis: parsed
    }
  rescue JSON::ParserError
    fallback_detect(combined_message)
  end

  def fallback_detect(message)
    intents = []

    intents << :greeting if message.match?(/merhaba|selam|günaydın|iyi\s*günler/i)
    intents << :thanks if message.match?(/teşekkür|sağol/i)
    intents << :farewell if message.match?(/görüşürüz|hoşça\s*kal/i)
    intents << :order_query if message.match?(/sipariş|kargo|teslimat/i)
    intents << :human_request if message.match?(/müşteri\s*temsilci|insan|canlı\s*destek/i)

    confidence_result = calculate_product_confidence(message)

    if confidence_result[:has_product_words]
      if confidence_result[:confidence] >= CONFIDENCE_HIGH
        intents << :product_query
      else
        intents << :clarification_needed
      end
    end

    intents << :general_question if intents.empty? && message.match?(/\?/)
    intents << :other if intents.empty?

    keywords = (
      confidence_result[:category_matches] +
      confidence_result[:attribute_matches] +
      confidence_result[:color_matches]
    ).uniq

    {
      intents: intents.uniq,
      product_keywords: keywords.first(5),
      combined_message: message,
      confidence: confidence_result[:confidence],
      confidence_details: confidence_result,
      raw_analysis: nil
    }
  end
end
