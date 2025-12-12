class Saturn::Llm::SemanticFaqService
  def initialize
    @hybrid_service = Saturn::Llm::HybridSearchService.new
  end

  # Kullanıcı sorusuna en benzer SSS'leri bulur (Hibrit Arama)
  # Hem semantic (anlamsal) hem de keyword (tam eşleşme) araması yapar
  def find_relevant_faqs(assistant:, query:, limit: 5)
    return [] if query.blank?

    # Hibrit arama kullan (semantic + keyword)
    @hybrid_service.search_faqs(
      assistant: assistant,
      query: query,
      limit: limit
    )
  rescue StandardError => e
    Rails.logger.error "[SEMANTIC FAQ] Hybrid search error: #{e.message}"
    # Hata durumunda fallback: basit metin araması
    fallback_search(assistant, query, limit)
  end

  private

  # Hibrit arama başarısız olursa basit metin araması yap
  def fallback_search(assistant, query, limit)
    Rails.logger.info "[SEMANTIC FAQ] Using fallback text search"
    assistant.responses
             .approved
             .where('question ILIKE ? OR answer ILIKE ?', "%#{query}%", "%#{query}%")
             .limit(limit)
  end
end

