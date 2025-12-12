class Saturn::Llm::ResponseValidatorService
  # AI yanıtını doğrular ve halüsinasyon riskini değerlendirir

  CONFIDENCE_PATTERNS = {
    high: /\[GÜVEN:\s*YÜKSEK\]/i,
    medium: /\[GÜVEN:\s*ORTA\]/i,
    low: /\[GÜVEN:\s*DÜŞÜK\]/i
  }.freeze

  CITATION_PATTERNS = {
    faq: /\[SSS_(\d+)\]/i,
    document: /\[DOKÜMAN_(\d+)\]/i
  }.freeze

  NO_INFO_PHRASES = [
    'elimde yeterli bilgi bulunmuyor',
    'bu konuda bilgim yok',
    'müşteri hizmetlerine',
    'bilgi bulunamadı',
    'emin değilim',
    'net bir bilgi veremiyorum'
  ].freeze

  HALLUCINATION_INDICATORS = [
    'genellikle',
    'muhtemelen',
    'sanırım',
    'tahminimce',
    'büyük ihtimalle',
    'normalde',
    'tipik olarak',
    'çoğu zaman'
  ].freeze

  def initialize(response:, available_faq_ids: [], available_document_ids: [])
    @response = response.to_s
    @available_faq_ids = available_faq_ids.map(&:to_i)
    @available_document_ids = available_document_ids.map(&:to_i)
  end

  def validate
    {
      response: @response,
      confidence: extract_confidence,
      citations: extract_citations,
      has_valid_citations: has_valid_citations?,
      has_no_info_response: has_no_info_response?,
      hallucination_risk: calculate_hallucination_risk,
      validation_passed: validation_passed?,
      cleaned_response: clean_response
    }
  end

  # Sadece güven seviyesini çıkar
  def extract_confidence
    return :high if @response.match?(CONFIDENCE_PATTERNS[:high])
    return :medium if @response.match?(CONFIDENCE_PATTERNS[:medium])
    return :low if @response.match?(CONFIDENCE_PATTERNS[:low])

    # Güven belirtilmemişse, citation'lara göre tahmin et
    infer_confidence_from_citations
  end

  # Tüm citation'ları çıkar
  def extract_citations
    faq_citations = @response.scan(CITATION_PATTERNS[:faq]).flatten.map(&:to_i)
    doc_citations = @response.scan(CITATION_PATTERNS[:document]).flatten.map(&:to_i)

    {
      faqs: faq_citations,
      documents: doc_citations,
      total: faq_citations.size + doc_citations.size
    }
  end

  # Citation'ların geçerli olup olmadığını kontrol et
  def has_valid_citations?
    citations = extract_citations

    # Hiç citation yoksa ve "bilmiyorum" yanıtı da yoksa, riskli
    return true if has_no_info_response?
    return false if citations[:total].zero?

    # Citation'ların gerçek kaynaklara işaret edip etmediğini kontrol et
    valid_faq_citations = citations[:faqs].all? { |id| id <= @available_faq_ids.size }
    valid_doc_citations = citations[:documents].all? { |id| @available_document_ids.include?(id) }

    valid_faq_citations && valid_doc_citations
  end

  # "Bilmiyorum" tipi yanıt mı?
  def has_no_info_response?
    normalized = @response.downcase
    NO_INFO_PHRASES.any? { |phrase| normalized.include?(phrase) }
  end

  # Halüsinasyon riskini hesapla
  def calculate_hallucination_risk
    risk_score = 0
    reasons = []

    # Citation yoksa risk yüksek
    citations = extract_citations
    if citations[:total].zero? && !has_no_info_response?
      risk_score += 40
      reasons << 'Kaynak gösterilmemiş'
    end

    # Halüsinasyon göstergeleri varsa risk yüksek
    normalized = @response.downcase
    found_indicators = HALLUCINATION_INDICATORS.select { |ind| normalized.include?(ind) }
    if found_indicators.any?
      risk_score += 10 * found_indicators.size
      reasons << "Belirsiz ifadeler: #{found_indicators.join(', ')}"
    end

    # Sayısal veri varsa ve citation yoksa risk yüksek
    has_numbers = @response.match?(/\d+\s*(TL|lira|gün|saat|dakika|ay|yıl|%|adet|kg|gram|cm|metre)/i)
    if has_numbers && citations[:total].zero?
      risk_score += 30
      reasons << 'Sayısal veri var ama kaynak yok'
    end

    # Risk seviyesi belirle
    risk_level = case risk_score
                 when 0..20 then :low
                 when 21..50 then :medium
                 else :high
                 end

    {
      score: [risk_score, 100].min,
      level: risk_level,
      reasons: reasons
    }
  end

  # Validasyonu geçti mi?
  def validation_passed?
    risk = calculate_hallucination_risk
    risk[:level] != :high
  end

  # Yanıtı temizle (meta etiketleri kaldır)
  def clean_response
    cleaned = @response.dup

    # Güven etiketlerini kaldır
    CONFIDENCE_PATTERNS.each_value { |pattern| cleaned.gsub!(pattern, '') }

    # Fazla boşlukları temizle
    cleaned.gsub(/\s+/, ' ').strip
  end

  private

  def infer_confidence_from_citations
    citations = extract_citations

    return :low if citations[:total].zero? && !has_no_info_response?
    return :medium if citations[:total].zero? && has_no_info_response?
    return :high if citations[:total] >= 2

    :medium
  end
end

