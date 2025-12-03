# Multi-Intent Detection Service
# Birden fazla mesajı analiz edip intent'leri tespit eder
#
# Örnek:
#   messages = ["merhaba", "halhal var mı?", "fiyatı ne kadar?"]
#   service = Saturn::MultiIntentDetectionService.new(assistant: assistant, messages: messages)
#   result = service.detect
#   # => { intents: [:greeting, :product_query], product_keywords: ["halhal"], ... }

class Saturn::MultiIntentDetectionService
  INTENT_TYPES = {
    greeting: 'Selamlama - merhaba, selam, günaydın vb.',
    farewell: 'Vedalaşma - görüşürüz, hoşçakal vb.',
    thanks: 'Teşekkür - teşekkürler, sağol vb.',
    product_query: 'Ürün sorgusu - ürün arama, fiyat sorma, stok kontrolü',
    order_query: 'Sipariş sorgusu - sipariş durumu, kargo takibi',
    general_question: 'Genel soru - SSS, bilgi talebi',
    complaint: 'Şikayet - problem bildirimi, memnuniyetsizlik',
    human_request: 'İnsan talebi - müşteri temsilcisi isteme',
    confirmation: 'Onay/Red - evet, hayır, tamam',
    other: 'Diğer - sınıflandırılamayan'
  }.freeze

  # Ürün araması gerektirmeyen intent'ler
  NON_PRODUCT_INTENTS = %i[greeting farewell thanks confirmation human_request].freeze

  def initialize(assistant:, messages:)
    @assistant = assistant
    @messages = Array(messages).map(&:to_s).reject(&:blank?)
  end

  def detect
    return empty_result if @messages.empty?

    # Tek mesaj ve basit pattern ise hızlı kontrol
    if @messages.size == 1 && simple_intent?(@messages.first)
      return quick_detect(@messages.first)
    end

    # LLM ile detaylı analiz
    llm_detect
  end

  # Ürün araması yapılmalı mı?
  def should_search_products?
    result = detect
    intents = result[:intents] || []

    # Ürün sorgusu varsa ve sadece non-product intent'ler değilse
    return true if intents.include?(:product_query)

    # Tüm intent'ler non-product ise arama yapma
    return false if intents.all? { |i| NON_PRODUCT_INTENTS.include?(i) }

    # Ürünle ilgili keyword varsa arama yap
    result[:product_keywords].present?
  end

  private

  def empty_result
    {
      intents: [],
      product_keywords: [],
      combined_message: '',
      raw_analysis: nil
    }
  end

  # Basit pattern kontrolü - LLM çağrısı yapmadan hızlı tespit
  def simple_intent?(message)
    clean = message.strip.downcase

    # Ürün kelimeleri içeriyorsa basit değil
    product_words = /kolye|bileklik|yüzük|küpe|halhal|taşlı|altın|gümüş|çelik|inci|siyah|beyaz|mor|fuşya|pembe|mavi|yeşil|gold|silver/i
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

  # Hızlı intent tespiti (LLM kullanmadan)
  def quick_detect(message)
    clean = message.strip.downcase
    intents = []

    intents << :greeting if clean.match?(/\A(merhaba|selam|hey|hi|hello|günaydın|iyi\s*günler)/i)
    intents << :farewell if clean.match?(/\A(görüşürüz|hoşça\s*kal|bye|güle\s*güle)/i)
    intents << :thanks if clean.match?(/\A(teşekkür|sağol|thanks)/i)
    intents << :confirmation if clean.match?(/\A(evet|hayır|tamam|ok|peki|olur|olmaz)/i)

    # Ürün sorgusu kontrolü (kısa mesajlarda bile)
    product_words = /kolye|bileklik|yüzük|küpe|halhal|taşlı|altın|gümüş|çelik|inci|siyah|beyaz|mor|fuşya|pembe|mavi|yeşil|gold|silver/i
    if clean.match?(product_words)
      intents << :product_query
      stop_words = %w[var mı mi mu mü ne kaç]
      keywords = clean.scan(/[\p{L}]+/).select { |w| w.length > 2 }.reject { |w| stop_words.include?(w) }
      
      return {
        intents: [:product_query],
        product_keywords: keywords,
        combined_message: message,
        raw_analysis: nil,
        quick_detect: true
      }
    end

    intents << :other if intents.empty?

    {
      intents: intents,
      product_keywords: [],
      combined_message: message,
      raw_analysis: nil,
      quick_detect: true
    }
  end

  # LLM ile detaylı intent analizi
  def llm_detect
    combined_message = @messages.join("\n")

    prompt = build_analysis_prompt(combined_message)

    begin
      response = call_llm(prompt)
      parse_llm_response(response, combined_message)
    rescue StandardError => e
      Rails.logger.error "[MULTI INTENT] LLM analysis failed: #{e.message}"
      fallback_detect(combined_message)
    end
  end

  def build_analysis_prompt(message)
    <<~PROMPT
      Aşağıdaki müşteri mesaj(lar)ını analiz et ve intent'leri tespit et.

      Müşteri Mesajı:
      #{message}

      Tespit edilebilecek intent türleri:
      - greeting: Selamlama (merhaba, selam, günaydın)
      - farewell: Vedalaşma (görüşürüz, hoşçakal)
      - thanks: Teşekkür (teşekkürler, sağol)
      - product_query: Ürün sorgusu (ürün arama, fiyat sorma, stok kontrolü, ürün özellikleri)
      - order_query: Sipariş sorgusu (sipariş durumu, kargo takibi)
      - general_question: Genel soru (SSS, bilgi talebi)
      - complaint: Şikayet (problem bildirimi)
      - human_request: İnsan talebi (müşteri temsilcisi isteme)
      - confirmation: Onay/Red (evet, hayır, tamam)
      - other: Diğer

      SADECE aşağıdaki JSON formatında yanıt ver, başka bir şey yazma:
      {
        "intents": ["intent1", "intent2"],
        "product_keywords": ["keyword1", "keyword2"],
        "summary": "Mesajın kısa özeti"
      }

      Önemli:
      - Birden fazla intent olabilir (örn: selamlama + ürün sorgusu)
      - product_keywords: Sadece ürün araması yapılacaksa, aranacak kelimeleri yaz
      - Eğer sadece selamlama/teşekkür/veda ise product_keywords boş olmalı
    PROMPT
  end

  def call_llm(prompt)
    client = OpenAI::Client.new(access_token: GlobalConfigService.load('OPENAI_API_KEY', nil))

    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.1,
        max_tokens: 300
      }
    )

    response.dig('choices', 0, 'message', 'content')
  end

  def parse_llm_response(response, combined_message)
    return fallback_detect(combined_message) if response.blank?

    # JSON'u parse et
    json_match = response.match(/\{[\s\S]*\}/)
    return fallback_detect(combined_message) unless json_match

    parsed = JSON.parse(json_match[0])

    intents = (parsed['intents'] || []).map { |i| i.to_s.downcase.to_sym }
    intents = [:other] if intents.empty?

    {
      intents: intents,
      product_keywords: parsed['product_keywords'] || [],
      combined_message: combined_message,
      summary: parsed['summary'],
      raw_analysis: parsed
    }
  rescue JSON::ParserError => e
    Rails.logger.warn "[MULTI INTENT] JSON parse error: #{e.message}"
    fallback_detect(combined_message)
  end

  # LLM başarısız olursa fallback
  def fallback_detect(message)
    intents = []
    keywords = []

    # Basit pattern matching
    intents << :greeting if message.match?(/merhaba|selam|günaydın|iyi\s*günler/i)
    intents << :thanks if message.match?(/teşekkür|sağol/i)
    intents << :farewell if message.match?(/görüşürüz|hoşça\s*kal/i)
    intents << :order_query if message.match?(/sipariş|kargo|teslimat/i)
    intents << :human_request if message.match?(/müşteri\s*temsilci|insan|canlı\s*destek/i)

    # Ürün sorgusu tespiti - Genişletilmiş pattern'ler
    # Ürün kategorileri
    product_categories = /kolye|bileklik|yüzük|küpe|halhal|set|takı|aksesuar|zincir|madalyon|charm/i
    # Ürün özellikleri
    product_attributes = /taşlı|altın|gümüş|çelik|inci|pırlanta|zirkon|baget|dorika/i
    # Renkler
    color_patterns = /siyah|beyaz|mor|fuşya|pembe|mavi|yeşil|kırmızı|sarı|turuncu|gold|silver|rose/i
    # Genel ürün kelimeleri
    general_product = /fiyat|ürün|stok|var\s*mı|kaç\s*tl|ne\s*kadar|bedeni?|rengi?|modeli?/i

    is_product_query = message.match?(product_categories) ||
                       message.match?(product_attributes) ||
                       message.match?(color_patterns) ||
                       message.match?(general_product)

    if is_product_query
      intents << :product_query
      # Basit keyword çıkarımı - stop words hariç
      stop_words = %w[var mı mi mu mü ne kaç tl lira nasıl nedir bir ve ile de da için]
      keywords = message.downcase
                        .scan(/[\p{L}]+/)
                        .select { |w| w.length > 2 }
                        .reject { |w| stop_words.include?(w) }
      Rails.logger.info "[MULTI INTENT] Fallback detected product_query with keywords: #{keywords.inspect}"
    end

    intents << :general_question if intents.empty? && message.match?(/\?/)
    intents << :other if intents.empty?

    {
      intents: intents.uniq,
      product_keywords: keywords.first(5),
      combined_message: message,
      raw_analysis: nil,
      fallback: true
    }
  end
end

