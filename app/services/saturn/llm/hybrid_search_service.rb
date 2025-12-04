class Saturn::Llm::HybridSearchService
  # Hibrit arama: Semantic + Keyword aramasını birleştirir
  # Bu sayede hem anlamsal benzerlik hem de tam eşleşme yakalanır

  SEMANTIC_WEIGHT = 0.6  # Semantic sonuçların ağırlığı
  KEYWORD_WEIGHT = 0.4   # Keyword sonuçların ağırlığı

  def initialize
    @embedding_service = Saturn::Llm::EmbeddingService.new
  end

  # SSS için hibrit arama
  def search_faqs(assistant:, query:, limit: 5)
    return [] if query.blank?

    # 1. Semantic Search
    semantic_results = semantic_faq_search(assistant, query, limit * 2)
    
    # 2. Keyword Search (tam eşleşme)
    keyword_results = keyword_faq_search(assistant, query, limit * 2)
    
    # 3. Sonuçları birleştir (RRF - Reciprocal Rank Fusion)
    merged_results = merge_results(semantic_results, keyword_results, limit)
    
    Rails.logger.info "[HYBRID SEARCH] FAQs - Semantic: #{semantic_results.size}, Keyword: #{keyword_results.size}, Merged: #{merged_results.size}"
    
    merged_results
  end

  # Döküman chunk'ları için hibrit arama
  def search_document_chunks(assistant:, query:, limit: 5)
    return [] if query.blank?

    # 1. Semantic Search
    semantic_results = semantic_chunk_search(assistant, query, limit * 2)
    
    # 2. Keyword Search
    keyword_results = keyword_chunk_search(assistant, query, limit * 2)
    
    # 3. Sonuçları birleştir
    merged_results = merge_results(semantic_results, keyword_results, limit)
    
    Rails.logger.info "[HYBRID SEARCH] Chunks - Semantic: #{semantic_results.size}, Keyword: #{keyword_results.size}, Merged: #{merged_results.size}"
    
    merged_results
  end

  private

  # ===== FAQ SEARCHES =====

  def semantic_faq_search(assistant, query, limit)
    query_embedding = @embedding_service.create_vector_embedding(query)
    
    assistant.responses
             .approved
             .where.not(embedding: nil)
             .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
             .limit(limit)
             .to_a
  rescue StandardError => e
    Rails.logger.error "[HYBRID SEARCH] Semantic FAQ error: #{e.message}"
    []
  end

  def keyword_faq_search(assistant, query, limit)
    # Sorguyu kelimelere ayır
    search_terms = extract_search_terms(query)
    return [] if search_terms.empty?

    # Her kelime için OR araması
    conditions = search_terms.map do |term|
      sanitized = ActiveRecord::Base.sanitize_sql_like(term)
      "(LOWER(question) LIKE '%#{sanitized}%' OR LOWER(answer) LIKE '%#{sanitized}%')"
    end.join(' OR ')

    assistant.responses
             .approved
             .where(conditions)
             .limit(limit)
             .to_a
  rescue StandardError => e
    Rails.logger.error "[HYBRID SEARCH] Keyword FAQ error: #{e.message}"
    []
  end

  # ===== CHUNK SEARCHES =====

  def semantic_chunk_search(assistant, query, limit)
    query_embedding = @embedding_service.create_vector_embedding(query)
    document_ids = assistant.documents.available.pluck(:id)
    return [] if document_ids.empty?

    Saturn::DocumentChunk
      .where(document_id: document_ids)
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
      .limit(limit)
      .includes(:document)
      .to_a
  rescue StandardError => e
    Rails.logger.error "[HYBRID SEARCH] Semantic chunk error: #{e.message}"
    []
  end

  def keyword_chunk_search(assistant, query, limit)
    search_terms = extract_search_terms(query)
    return [] if search_terms.empty?

    document_ids = assistant.documents.available.pluck(:id)
    return [] if document_ids.empty?

    conditions = search_terms.map do |term|
      sanitized = ActiveRecord::Base.sanitize_sql_like(term)
      "LOWER(content) LIKE '%#{sanitized}%'"
    end.join(' OR ')

    Saturn::DocumentChunk
      .where(document_id: document_ids)
      .where(conditions)
      .limit(limit)
      .includes(:document)
      .to_a
  rescue StandardError => e
    Rails.logger.error "[HYBRID SEARCH] Keyword chunk error: #{e.message}"
    []
  end

  # ===== MERGE LOGIC =====

  def merge_results(semantic_results, keyword_results, limit)
    # Reciprocal Rank Fusion (RRF) algoritması
    # Her sonuç için skor hesapla: 1 / (k + rank)
    # k = 60 (standart RRF sabiti)
    k = 60

    scores = Hash.new(0)
    result_objects = {}

    # Semantic sonuçları skorla
    semantic_results.each_with_index do |result, rank|
      id = result.id
      scores[id] += SEMANTIC_WEIGHT * (1.0 / (k + rank + 1))
      result_objects[id] = result
    end

    # Keyword sonuçları skorla
    keyword_results.each_with_index do |result, rank|
      id = result.id
      scores[id] += KEYWORD_WEIGHT * (1.0 / (k + rank + 1))
      result_objects[id] = result
    end

    # Skora göre sırala ve limit uygula
    sorted_ids = scores.sort_by { |_id, score| -score }.first(limit).map(&:first)
    
    sorted_ids.map { |id| result_objects[id] }
  end

  def extract_search_terms(query)
    # Sorgudan arama terimlerini çıkar
    # - Küçük harfe çevir
    # - Stop word'leri kaldır
    # - 2 karakterden kısa kelimeleri kaldır
    # - Özel karakterleri temizle
    
    stop_words = %w[
      bir ve ile de da için ne nasıl nedir mi mı mu mü
      bu şu o ben sen biz siz onlar var yok
      a an the is are was were be been being
      to of in for on with at by from
    ]

    query.downcase
         .gsub(/[^\p{L}\p{N}\s]/, ' ')  # Harf ve rakam dışındakileri temizle
         .split
         .reject { |word| word.length < 2 }
         .reject { |word| stop_words.include?(word) }
         .uniq
         .first(10)  # Max 10 terim
  end
end

