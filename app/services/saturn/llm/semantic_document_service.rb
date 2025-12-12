class Saturn::Llm::SemanticDocumentService
  MAX_RELEVANT_CHUNKS = 5

  def initialize
    @hybrid_service = Saturn::Llm::HybridSearchService.new
    @embedding_service = Saturn::Llm::EmbeddingService.new
  end

  # Kullanıcı sorgusuna en alakalı döküman chunk'larını bul (Hibrit Arama)
  # Hem semantic (anlamsal) hem de keyword (tam eşleşme) araması yapar
  def find_relevant_chunks(assistant:, query:, limit: MAX_RELEVANT_CHUNKS)
    return [] if query.blank?

    # Hibrit arama kullan (semantic + keyword)
    @hybrid_service.search_document_chunks(
      assistant: assistant,
      query: query,
      limit: limit
    )
  rescue StandardError => e
    Rails.logger.error "[SEMANTIC DOC] Hybrid search error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    []
  end

  # Tek bir döküman için en alakalı chunk'ları bul (sadece semantic)
  def find_relevant_chunks_for_document(document:, query:, limit: 3)
    return [] if query.blank? || document.nil?

    begin
      query_embedding = @embedding_service.create_vector_embedding(query)
    rescue Saturn::Llm::EmbeddingService::EmbeddingsError => e
      Rails.logger.error "[SEMANTIC DOC] Failed to create query embedding: #{e.message}"
      return []
    end

    document.chunks
            .with_embedding
            .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
            .limit(limit)
  rescue StandardError => e
    Rails.logger.error "[SEMANTIC DOC] Error finding chunks for document: #{e.message}"
    []
  end
end

