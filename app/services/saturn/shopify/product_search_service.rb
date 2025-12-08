# Shopify ürünlerini semantic + keyword arama ile bulur
class Saturn::Shopify::ProductSearchService
  MAX_PRODUCTS = 5
  MIN_SEMANTIC_SIMILARITY = 0.3 # Minimum cosine similarity threshold
  
  # Rerank sabitleri
  RERANK_CANDIDATES = 10  # Vector search'den alınacak aday sayısı
  RERANK_FINAL = 3        # LLM rerank sonrası döndürülecek ürün sayısı

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

  # ============================================================
  # YENİ YAKLAŞIM: Keyword Boost + Vector Search + LLM Reranking
  # ============================================================
  # 1. Keyword match ürünleri bul (öncelikli - "siyah" kelimesi varsa)
  # 2. Vector search ile aday ürün bul
  # 3. İkisini birleştir (keyword öncelikli)
  # 4. LLM ile rerank et
  # ============================================================
  def search_with_rerank(query:, candidates_limit: RERANK_CANDIDATES, final_limit: RERANK_FINAL)
    return [] if query.blank?
    return [] unless available?
    return [] if product_count.zero?

    clean_query = sanitize_query(query)
    return [] if clean_query.blank?

    Rails.logger.info "[SHOPIFY RERANK] 🔍 Query: '#{clean_query}'"

    # 1. Keyword match ürünleri bul (öncelikli)
    keyword_products = keyword_search_for_rerank(clean_query, candidates_limit)
    Rails.logger.info "[SHOPIFY RERANK] 🔑 Keyword match: #{keyword_products.size} products"

    # 2. Vector search ile aday ürünleri bul
    vector_products = vector_only_search(clean_query, candidates_limit)
    Rails.logger.info "[SHOPIFY RERANK] 🧠 Vector search: #{vector_products.size} products"

    # 3. Birleştir: Keyword önce, sonra vector (duplicate'leri kaldır)
    keyword_ids = keyword_products.map(&:id)
    unique_vector = vector_products.reject { |p| keyword_ids.include?(p.id) }
    all_candidates = (keyword_products + unique_vector)

    # 4. Stoksuz ürünleri filtrele
    candidates = all_candidates.select { |p| p.total_inventory.to_i.positive? }.first(candidates_limit)
    out_of_stock_count = all_candidates.size - candidates.size
    Rails.logger.info "[SHOPIFY RERANK] 📦 Filtered out #{out_of_stock_count} out-of-stock products" if out_of_stock_count.positive?

    if candidates.empty?
      Rails.logger.info '[SHOPIFY RERANK] ❌ No candidates found (all out of stock)'
      return []
    end

    Rails.logger.info "[SHOPIFY RERANK] 📦 Total candidates: #{candidates.size} (after stock filter)"

    # Eğer final_limit veya daha az sonuç varsa, rerank'a gerek yok
    if candidates.size <= final_limit
      Rails.logger.info '[SHOPIFY RERANK] ⏭️ Skipping rerank (few candidates)'
      return candidates
    end

    # 4. LLM ile rerank yap
    reranked = llm_rerank_products(clean_query, candidates, final_limit)

    Rails.logger.info "[SHOPIFY RERANK] ✅ Final results: #{reranked.size}"
    reranked
  end

  # Keyword arama (rerank için) - title, description ve varyantlarda arar
  def keyword_search_for_rerank(query, limit)
    search_terms = extract_search_terms(query)
    return [] if search_terms.empty?

    # Her keyword için ILIKE ile ara (title, description VE variants içinde)
    conditions = search_terms.map do |term|
      sanitized = ActiveRecord::Base.sanitize_sql_like(term)
      "(LOWER(title) LIKE '%#{sanitized}%' OR LOWER(description) LIKE '%#{sanitized}%' OR LOWER(variants::text) LIKE '%#{sanitized}%')"
    end.join(' AND ')

    results = Shopify::Product
              .for_account(@account.id)
              .where(conditions)
              .limit(limit)
              .to_a

    # AND eşleşme yoksa OR ile dene
    if results.empty?
      or_conditions = search_terms.map do |term|
        sanitized = ActiveRecord::Base.sanitize_sql_like(term)
        "(LOWER(title) LIKE '%#{sanitized}%' OR LOWER(description) LIKE '%#{sanitized}%' OR LOWER(variants::text) LIKE '%#{sanitized}%')"
      end.join(' OR ')

      results = Shopify::Product
                .for_account(@account.id)
                .where(or_conditions)
                .limit(limit)
                .to_a
    end

    Rails.logger.info "[SHOPIFY RERANK] Keyword search found #{results.size} products (title, description, variants)"
    results
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY RERANK] Keyword search failed: #{e.message}"
    []
  end

  private

  # Sadece vector/semantic search (rerank için)
  def vector_only_search(query, limit)
    query_embedding = @embedding_service.create_vector_embedding(query)

    results = Shopify::Product
              .for_account(@account.id)
              .where.not(embedding: nil)
              .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
              .limit(limit)
              .to_a

    # Similarity skorlarını logla
    results.each do |product|
      similarity = (1.0 - product.neighbor_distance) * 100
      Rails.logger.debug "[SHOPIFY RERANK] 📊 Candidate: '#{product.title}' (similarity: #{similarity.round(1)}%)"
    end

    results
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY RERANK] Vector search failed: #{e.message}"
    []
  end

  # LLM ile ürünleri rerank et
  def llm_rerank_products(query, products, limit)
    prompt = build_rerank_prompt(query, products)

    response = call_rerank_llm(prompt)
    selected_ids = parse_rerank_response(response, products.map(&:id))

    # Seçilen ID'lere göre ürünleri sırala
    reranked = selected_ids.first(limit).filter_map do |id|
      products.find { |p| p.id == id }
    end

    # Rerank sonucunu logla
    Rails.logger.info '[SHOPIFY RERANK] 🏆 LLM Ranking:'
    reranked.each_with_index do |p, i|
      Rails.logger.info "[SHOPIFY RERANK]   #{i + 1}. '#{p.title}'"
    end

    reranked
  rescue StandardError => e
    Rails.logger.error "[SHOPIFY RERANK] LLM rerank failed: #{e.message}"
    # Fallback: Vector sıralamasını kullan
    products.first(limit)
  end

  def build_rerank_prompt(query, products)
    products_text = products.map.with_index do |p, i|
      price_text = if p.min_price == p.max_price
                     "₺#{p.min_price}"
                   else
                     "₺#{p.min_price}-#{p.max_price}"
                   end
      desc_short = p.description.to_s.gsub(/<[^>]*>/, '').strip.truncate(100)
      "#{i + 1}. [ID:#{p.id}] #{p.title} | #{p.vendor} | #{p.product_type} | #{price_text}\n   #{desc_short}"
    end.join("\n")

    <<~PROMPT
      Kullanıcı şunu arıyor: "#{query}"

      Aşağıdaki ürünlerden kullanıcının ihtiyacına EN UYGUN 3 tanesini seç.
      Seçerken şunlara dikkat et:
      - Kullanıcının aradığı özellikler (renk, tarz, kategori vb.)
      - Ürün açıklaması ve başlığındaki eşleşmeler
      - Fiyat ve marka uygunluğu

      ÜRÜNLER:
      #{products_text}

      SADECE aşağıdaki JSON formatında yanıt ver, başka bir şey yazma:
      {"selected_ids": [ID1, ID2, ID3], "reason": "seçim nedeni"}
    PROMPT
  end

  def call_rerank_llm(prompt)
    # Account-specific key veya Super Admin key
    account = @account
    api_key = account&.openai_api_key&.presence
    api_key ||= InstallationConfig.find_by(name: 'SATURN_OPEN_AI_API_KEY')&.value
    
    if api_key.blank?
      Rails.logger.error '[SHOPIFY RERANK] OPENAI_API_KEY not configured'
      raise 'OpenAI API key not configured'
    end
    
    # Custom endpoint desteği
    endpoint_config = InstallationConfig.find_by(name: 'SATURN_OPEN_AI_ENDPOINT')&.value
    endpoint = endpoint_config.presence || 'https://api.openai.com/'
    
    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: endpoint.chomp('/')
    )

    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini', # Hızlı ve ekonomik
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.1,     # Düşük = tutarlı sonuç
        max_tokens: 200
      }
    )

    response.dig('choices', 0, 'message', 'content')
  end

  def parse_rerank_response(response, valid_ids)
    json_match = response.to_s.match(/\{[\s\S]*\}/)
    return valid_ids.first(RERANK_FINAL) unless json_match

    parsed = JSON.parse(json_match[0])
    selected = parsed['selected_ids'] || []

    Rails.logger.info "[SHOPIFY RERANK] 💡 LLM reason: #{parsed['reason']}"

    # Sadece geçerli ID'leri döndür
    valid_selected = selected.select { |id| valid_ids.include?(id) }

    # Eğer LLM geçersiz ID verdiyse, fallback
    return valid_ids.first(RERANK_FINAL) if valid_selected.empty?

    valid_selected
  rescue JSON::ParserError => e
    Rails.logger.error "[SHOPIFY RERANK] JSON parse error: #{e.message}"
    valid_ids.first(RERANK_FINAL)
  end

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

