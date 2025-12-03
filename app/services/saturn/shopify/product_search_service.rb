# Shopify ürünlerini semantic + keyword arama ile bulur
class Saturn::Shopify::ProductSearchService
  MAX_PRODUCTS = 5
  MIN_SEMANTIC_SIMILARITY = 0.3 # Minimum cosine similarity threshold

  def initialize(account:)
    @account = account
    @embedding_service = Saturn::Llm::EmbeddingService.new
  end

  def available?
    hook = Integrations::Hook.find_by(account: @account, app_id: 'shopify')
    hook.present? && hook.enabled?
  end

  def product_count
    Shopify::Product.for_account(@account.id).count
  end

  # Hibrit arama: Semantic + Keyword
  # NOT: Intent kontrolü artık AssistantChatService'de yapılıyor
  def search(query:, limit: MAX_PRODUCTS)
    return [] if query.blank?
    return [] unless available?
    return [] if product_count.zero?

    # Sorguyu temizle - conversation prefix'lerini kaldır
    clean_query = sanitize_query(query)
    return [] if clean_query.blank?

    # Search terms'i instance variable olarak sakla (merge_results'da kullanılacak)
    @search_terms = extract_search_terms(clean_query)

    Rails.logger.info "[SHOPIFY SEARCH] Original query: '#{query.to_s.truncate(80)}'"
    Rails.logger.info "[SHOPIFY SEARCH] Cleaned query: '#{clean_query}'"
    Rails.logger.info "[SHOPIFY SEARCH] Search terms: #{@search_terms.inspect}"

    # 1. Semantic Search (benzerlik skoru ile)
    semantic_results = semantic_search_with_threshold(clean_query, limit * 2)

    # 2. Keyword Search
    keyword_results = keyword_search(clean_query, limit * 2)

    # Hiç sonuç yoksa boş dön
    return [] if semantic_results.empty? && keyword_results.empty?

    # 3. Sonuçları birleştir (Improved RRF with keyword match boost)
    merged = merge_results(semantic_results, keyword_results, limit)

    Rails.logger.info "[SHOPIFY SEARCH] Results - Semantic: #{semantic_results.size}, Keyword: #{keyword_results.size}, Merged: #{merged.size}"

    merged
  end
  
  # Sorguyu temizle - conversation prefix'lerini ve gereksiz kelimeleri kaldır
  def sanitize_query(query)
    return '' if query.blank?
    
    # Multi-line sorgularda son satırı al (en son kullanıcı mesajı)
    lines = query.to_s.strip.split("\n")
    
    # Son satırı al (en güncel soru)
    last_line = lines.last.to_s.strip
    
    # "Kullanıcı:" veya "Asistan:" prefix'ini kaldır
    cleaned = last_line.gsub(/^(Kullanıcı|Asistan|User|Assistant):\s*/i, '')
    
    # Gereksiz boşlukları temizle
    cleaned.strip
  end

  # Ürünleri prompt formatında döndür
  def format_for_prompt(products)
    return nil if products.blank?

    formatted = products.map.with_index do |product, index|
      format_product(product, index + 1)
    end

    formatted.join("\n\n")
  end

  private

  # Semantic search with similarity threshold
  def semantic_search_with_threshold(query, limit)
    query_embedding = @embedding_service.create_vector_embedding(query)

    results = Shopify::Product
              .for_account(@account.id)
              .where.not(embedding: nil)
              .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
              .limit(limit * 2) # Daha fazla al, filtreleyeceğiz

    # Cosine distance'ı similarity'ye çevir ve eşiği uygula
    # Cosine distance = 1 - cosine_similarity
    # Yani distance < 0.7 => similarity > 0.3
    max_distance = 1.0 - MIN_SEMANTIC_SIMILARITY

    filtered = results.select do |product|
      distance = product.neighbor_distance
      if distance <= max_distance
        true
      else
        Rails.logger.debug "[SHOPIFY SEARCH] Product '#{product.title}' filtered out (distance: #{distance.round(3)}, threshold: #{max_distance})"
        false
      end
    end

    Rails.logger.info "[SHOPIFY SEARCH] Semantic: #{results.size} found, #{filtered.size} above threshold (min similarity: #{MIN_SEMANTIC_SIMILARITY})"

    filtered.first(limit)
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY SEARCH] Semantic search failed: #{e.message}"
    []
  end

  def semantic_search(query, limit)
    query_embedding = @embedding_service.create_vector_embedding(query)

    Shopify::Product
      .for_account(@account.id)
      .where.not(embedding: nil)
      .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
      .limit(limit)
      .to_a
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY SEARCH] Semantic search failed: #{e.message}"
    []
  end

  def keyword_search(query, limit)
    search_terms = extract_search_terms(query)
    return [] if search_terms.empty?

    conditions = search_terms.map do |term|
      sanitized = ActiveRecord::Base.sanitize_sql_like(term)
      "(LOWER(title) LIKE '%#{sanitized}%' OR LOWER(description) LIKE '%#{sanitized}%' OR LOWER(vendor) LIKE '%#{sanitized}%' OR LOWER(product_type) LIKE '%#{sanitized}%')"
    end.join(' OR ')

    Shopify::Product
      .for_account(@account.id)
      .where(conditions)
      .limit(limit)
      .to_a
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY SEARCH] Keyword search failed: #{e.message}"
    []
  end

  # Waterfall/Cascade yaklaşımı:
  # 1. Full match (tüm keyword'ler eşleşen) → öncelikli
  # 2. Partial keyword match → ikinci öncelik
  # 3. Semantic search → son çare
  def merge_results(semantic_results, keyword_results, limit)
    result_objects = {}
    final_results = []

    # Tüm ürünleri topla
    all_products = (semantic_results + keyword_results).uniq(&:id)
    all_products.each { |p| result_objects[p.id] = p }

    # Her ürün için keyword eşleşme sayısını hesapla
    products_with_matches = all_products.map do |product|
      match_count = count_keyword_matches(product)
      { product: product, matches: match_count }
    end

    total_terms = @search_terms&.size || 0

    # === 1. FULL MATCH: Tüm keyword'ler eşleşen ürünler ===
    full_matches = products_with_matches
                   .select { |p| p[:matches] == total_terms && total_terms > 0 }
                   .map { |p| p[:product] }

    if full_matches.any?
      Rails.logger.info "[SHOPIFY SEARCH] ✅ FULL MATCH found: #{full_matches.size} products"
      full_matches.each { |p| Rails.logger.info "[SHOPIFY SEARCH]   → '#{p.title}'" }
      final_results.concat(full_matches)
    end

    return final_results.first(limit) if final_results.size >= limit

    # === 2. PARTIAL KEYWORD MATCH: En az 2 keyword eşleşen ürünler ===
    partial_matches = products_with_matches
                      .select { |p| p[:matches] >= 2 && p[:matches] < total_terms }
                      .sort_by { |p| -p[:matches] }
                      .map { |p| p[:product] }
                      .reject { |p| final_results.map(&:id).include?(p.id) }

    if partial_matches.any?
      Rails.logger.info "[SHOPIFY SEARCH] 🔶 PARTIAL MATCH found: #{partial_matches.size} products"
      needed = limit - final_results.size
      final_results.concat(partial_matches.first(needed))
    end

    return final_results.first(limit) if final_results.size >= limit

    # === 3. SINGLE KEYWORD MATCH: En az 1 keyword eşleşen ===
    single_matches = products_with_matches
                     .select { |p| p[:matches] == 1 }
                     .map { |p| p[:product] }
                     .reject { |p| final_results.map(&:id).include?(p.id) }

    if single_matches.any?
      Rails.logger.info "[SHOPIFY SEARCH] 🔹 SINGLE MATCH found: #{single_matches.size} products"
      needed = limit - final_results.size
      final_results.concat(single_matches.first(needed))
    end

    return final_results.first(limit) if final_results.size >= limit

    # === 4. SEMANTIC ONLY: Keyword eşleşmesi olmayan semantic sonuçlar ===
    semantic_only = semantic_results.reject { |p| final_results.map(&:id).include?(p.id) }

    if semantic_only.any?
      Rails.logger.info "[SHOPIFY SEARCH] 🔸 SEMANTIC fill: #{semantic_only.size} products available"
      needed = limit - final_results.size
      final_results.concat(semantic_only.first(needed))
    end

    # Debug: Final sıralamayı logla
    Rails.logger.info "[SHOPIFY SEARCH] === FINAL RANKING ==="
    final_results.first(limit).each_with_index do |product, idx|
      matches = count_keyword_matches(product)
      match_type = case matches
                   when total_terms then '✅ FULL'
                   when 2.. then '🔶 PARTIAL'
                   when 1 then '🔹 SINGLE'
                   else '🔸 SEMANTIC'
                   end
      Rails.logger.info "[SHOPIFY SEARCH] #{idx + 1}. #{match_type} '#{product.title}' (#{matches}/#{total_terms})"
    end

    final_results.first(limit)
  end

  # Ürünün title ve description'ında kaç keyword eşleşiyor
  def count_keyword_matches(product)
    return 0 if @search_terms.blank?

    searchable_text = [
      product.title,
      product.description,
      product.vendor,
      product.product_type
    ].compact.join(' ').downcase

    @search_terms.count { |term| searchable_text.include?(term.downcase) }
  end

  def extract_search_terms(query)
    stop_words = %w[
      bir ve ile de da için ne nasıl nedir mi mı mu mü
      bu şu o ben sen biz siz onlar var yok
      a an the is are was were be been being
      to of in for on with at by from
      ürün ürünler fiyat fiyatı kaç ne kadar
    ]

    query.downcase
         .gsub(/[^\p{L}\p{N}\s]/, ' ')
         .split
         .reject { |word| word.length < 2 }
         .reject { |word| stop_words.include?(word) }
         .uniq
         .first(10)
  end

  def format_product(product, index)
    parts = ["[ÜRÜN_#{index}] **#{product.title}**"]

    if product.description.present?
      # Açıklamayı kısalt
      desc = product.description.gsub(/<[^>]*>/, '').strip.truncate(300)
      parts << "Açıklama: #{desc}"
    end

    # Fiyat bilgisi
    if product.min_price.present? && product.max_price.present?
      if product.min_price == product.max_price
        parts << "Fiyat: #{product.min_price} TL"
      else
        parts << "Fiyat: #{product.min_price} - #{product.max_price} TL"
      end
    elsif product.min_price.present?
      parts << "Fiyat: #{product.min_price} TL"
    end

    # Stok bilgisi
    if product.total_inventory.present?
      stock_status = product.total_inventory.positive? ? "Stokta (#{product.total_inventory} adet)" : 'Stokta Yok'
      parts << "Stok: #{stock_status}"
    end

    # Varyantlar
    if product.variants.present? && product.variants.is_a?(Array) && product.variants.size > 1
      variant_options = product.variants.map { |v| v['title'] }.compact.uniq.first(5)
      parts << "Seçenekler: #{variant_options.join(', ')}" if variant_options.any?
    end

    # Marka/Vendor
    parts << "Marka: #{product.vendor}" if product.vendor.present?

    parts.join("\n   ")
  end
end

