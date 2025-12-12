namespace :saturn do
  # ===== FAQ EMBEDDING TASKS =====
  
  desc 'Backfill embeddings for existing FAQs (SSS)'
  task backfill_faq_embeddings: :environment do
    puts 'Starting FAQ embedding backfill...'

    total = Saturn::AssistantResponse.where(embedding: nil).count
    puts "Found #{total} FAQs without embeddings"

    if total.zero?
      puts 'No FAQs to process. Done!'
      exit
    end

    processed = 0
    errors = 0

    Saturn::AssistantResponse.where(embedding: nil).find_each do |response|
      Saturn::UpdateFaqEmbeddingJob.perform_later(response.id)
      processed += 1
      print "\rQueued #{processed}/#{total} FAQs..."
    rescue StandardError => e
      errors += 1
      puts "\nError queueing FAQ ##{response.id}: #{e.message}"
    end

    puts "\n\nBackfill complete!"
    puts "  Queued: #{processed}"
    puts "  Errors: #{errors}"
    puts "\nNote: Jobs are running in background via Sidekiq."
    puts "Check Sidekiq dashboard for progress."
  end

  desc 'Check FAQ embedding status'
  task faq_embedding_status: :environment do
    total = Saturn::AssistantResponse.count
    with_embedding = Saturn::AssistantResponse.where.not(embedding: nil).count
    without_embedding = Saturn::AssistantResponse.where(embedding: nil).count

    puts 'FAQ Embedding Status:'
    puts "  Total FAQs: #{total}"
    puts "  With embedding: #{with_embedding} (#{(with_embedding.to_f / total * 100).round(1)}%)"
    puts "  Without embedding: #{without_embedding}"
  end

  desc 'Regenerate all FAQ embeddings (use with caution)'
  task regenerate_all_embeddings: :environment do
    puts 'WARNING: This will regenerate ALL FAQ embeddings!'
    puts 'This may incur OpenAI API costs.'
    print 'Continue? (yes/no): '

    # For non-interactive environments, check for FORCE flag
    if ENV['FORCE'] == 'true'
      confirm = 'yes'
    else
      confirm = $stdin.gets&.chomp
    end

    unless confirm == 'yes'
      puts 'Aborted.'
      exit
    end

    total = Saturn::AssistantResponse.count
    puts "Regenerating embeddings for #{total} FAQs..."

    Saturn::AssistantResponse.find_each do |response|
      Saturn::UpdateFaqEmbeddingJob.perform_later(response.id)
    end

    puts 'All jobs queued. Check Sidekiq for progress.'
  end

  # ===== DOCUMENT CHUNKING TASKS =====

  desc 'Create chunks for existing documents (backfill)'
  task backfill_document_chunks: :environment do
    puts 'Starting document chunking backfill...'

    # Chunk'ı olmayan veya içeriği olan ama chunk'ı olmayan dökümanları bul
    documents_to_process = Saturn::Document.available
                                           .where.not(content: [nil, ''])
                                           .left_joins(:chunks)
                                           .where(saturn_document_chunks: { id: nil })
                                           .distinct

    total = documents_to_process.count
    puts "Found #{total} documents without chunks"

    if total.zero?
      puts 'No documents to process. Done!'
      exit
    end

    processed = 0
    errors = 0

    documents_to_process.find_each do |document|
      service = Saturn::DocumentProcessingService.new(document)
      service.send(:create_document_chunks)
      processed += 1
      print "\rProcessed #{processed}/#{total} documents..."
    rescue StandardError => e
      errors += 1
      puts "\nError processing document ##{document.id}: #{e.message}"
    end

    puts "\n\nBackfill complete!"
    puts "  Processed: #{processed}"
    puts "  Errors: #{errors}"
    puts "\nChunk embeddings will be created automatically via background jobs."
  end

  desc 'Check document chunk status'
  task document_chunk_status: :environment do
    total_docs = Saturn::Document.available.count
    docs_with_chunks = Saturn::Document.available
                                       .joins(:chunks)
                                       .distinct
                                       .count
    docs_without_chunks = total_docs - docs_with_chunks

    total_chunks = Saturn::DocumentChunk.count
    chunks_with_embedding = Saturn::DocumentChunk.where.not(embedding: nil).count
    chunks_without_embedding = Saturn::DocumentChunk.where(embedding: nil).count

    puts 'Document Chunk Status:'
    puts '========================'
    puts "\nDocuments:"
    puts "  Total available: #{total_docs}"
    puts "  With chunks: #{docs_with_chunks}"
    puts "  Without chunks: #{docs_without_chunks}"
    puts "\nChunks:"
    puts "  Total: #{total_chunks}"
    puts "  With embedding: #{chunks_with_embedding} (#{total_chunks.positive? ? (chunks_with_embedding.to_f / total_chunks * 100).round(1) : 0}%)"
    puts "  Without embedding: #{chunks_without_embedding}"
  end

  desc 'Regenerate all document chunks (use with caution)'
  task regenerate_all_chunks: :environment do
    puts 'WARNING: This will DELETE and REGENERATE all document chunks!'
    puts 'This will also recreate all embeddings, incurring OpenAI API costs.'
    print 'Continue? (yes/no): '

    if ENV['FORCE'] == 'true'
      confirm = 'yes'
    else
      confirm = $stdin.gets&.chomp
    end

    unless confirm == 'yes'
      puts 'Aborted.'
      exit
    end

    documents = Saturn::Document.available.where.not(content: [nil, ''])
    total = documents.count
    puts "Regenerating chunks for #{total} documents..."

    processed = 0
    documents.find_each do |document|
      service = Saturn::DocumentProcessingService.new(document)
      service.send(:create_document_chunks)
      processed += 1
      print "\rProcessed #{processed}/#{total}..."
    rescue StandardError => e
      puts "\nError processing document ##{document.id}: #{e.message}"
    end

    puts "\n\nAll chunks regenerated. Embeddings being created via background jobs."
  end

  # ===== EMBEDDING CACHE TASKS =====

  desc 'Show embedding cache statistics'
  task cache_stats: :environment do
    stats = Saturn::Llm::EmbeddingService.cache_stats

    puts '=' * 50
    puts 'EMBEDDING CACHE STATISTICS'
    puts '=' * 50
    puts ''
    puts "📊 Cache Performance:"
    puts "   Total Requests: #{stats[:total_requests]}"
    puts "   Cache Hits: #{stats[:cache_hits]}"
    puts "   Cache Misses: #{stats[:cache_misses]}"
    puts "   Hit Rate: #{stats[:hit_rate_percent]}%"
    puts ''
    puts "💰 Cost Savings:"
    puts "   API Calls Made: #{stats[:api_calls]}"
    puts "   API Calls Saved: #{stats[:cache_hits]}"
    puts "   Estimated Savings: $#{stats[:estimated_savings_usd]}"
    puts ''
    puts '=' * 50
  end

  desc 'Reset embedding cache statistics'
  task reset_cache_stats: :environment do
    Saturn::Llm::EmbeddingService.reset_stats
    puts 'Cache statistics reset successfully.'
  end

  desc 'Clear all embedding cache'
  task clear_cache: :environment do
    puts 'WARNING: This will clear ALL embedding cache!'
    puts 'Cached embeddings will need to be regenerated.'
    print 'Continue? (yes/no): '

    if ENV['FORCE'] == 'true'
      confirm = 'yes'
    else
      confirm = $stdin.gets&.chomp
    end

    unless confirm == 'yes'
      puts 'Aborted.'
      exit
    end

    Saturn::Llm::EmbeddingService.clear_cache
    puts 'Embedding cache cleared successfully.'
  end

  # ===== PRODUCT EMBEDDING TASKS =====

  desc 'Backfill embeddings for Shopify products'
  task backfill_product_embeddings: :environment do
    puts 'Starting product embedding backfill...'

    total = Shopify::Product.where(embedding: nil).count
    puts "Found #{total} products without embeddings"

    if total.zero?
      puts 'No products to process. Done!'
      exit
    end

    processed = 0
    Shopify::Product.where(embedding: nil).find_each do |product|
      Shopify::UpdateProductEmbeddingJob.perform_later(product.id)
      processed += 1
      print "\rQueued #{processed}/#{total} products..."
    rescue StandardError => e
      puts "\nError queueing product ##{product.id}: #{e.message}"
    end

    puts "\n\nBackfill complete! Queued: #{processed}"
    puts 'Jobs running in background via Sidekiq.'
  end

  desc 'Check product embedding status'
  task product_embedding_status: :environment do
    total = Shopify::Product.count
    with_embedding = Shopify::Product.where.not(embedding: nil).count
    without_embedding = Shopify::Product.where(embedding: nil).count

    puts 'Product Embedding Status:'
    puts "  Total products: #{total}"
    puts "  With embedding: #{with_embedding} (#{total.positive? ? (with_embedding.to_f / total * 100).round(1) : 0}%)"
    puts "  Without embedding: #{without_embedding}"
  end

  desc 'Regenerate all product embeddings (includes variant info)'
  task regenerate_product_embeddings: :environment do
    puts 'WARNING: This will regenerate ALL product embeddings!'
    puts 'This includes variant titles (colors, sizes, etc.) for better search.'
    puts 'This may incur OpenAI API costs.'
    print 'Continue? (yes/no): '

    confirm = ENV['FORCE'] == 'true' ? 'yes' : $stdin.gets&.chomp

    unless confirm == 'yes'
      puts 'Aborted.'
      exit
    end

    total = Shopify::Product.count
    puts "Regenerating embeddings for #{total} products..."

    processed = 0
    Shopify::Product.find_each do |product|
      # Embedding'i sil ve yeniden oluştur
      product.update_column(:embedding, nil)
      product.update_embedding!
      processed += 1
      print "\rProcessed #{processed}/#{total}..."
    rescue StandardError => e
      puts "\nError processing product ##{product.id}: #{e.message}"
    end

    puts "\n\nAll product embeddings regenerated!"
  end

  desc 'Analyze product images with GPT-4o (for visual search)'
  task analyze_product_images: :environment do
    puts 'Starting product image analysis with GPT-4o...'
    puts 'This will analyze product images and create descriptions for visual search.'

    # Resmi olan ama analiz edilmemiş ürünleri bul
    products_to_analyze = Shopify::Product.where(image_analyzed_at: nil)
                                          .where.not(images: nil)
                                          .where.not(images: [])

    total = products_to_analyze.count
    puts "Found #{total} products to analyze"

    if total.zero?
      puts 'No products to analyze. Done!'
      exit
    end

    print 'Continue? (yes/no): '
    confirm = ENV['FORCE'] == 'true' ? 'yes' : $stdin.gets&.chomp

    unless confirm == 'yes'
      puts 'Aborted.'
      exit
    end

    processed = 0
    success = 0
    errors = 0

    products_to_analyze.find_each do |product|
      result = product.analyze_image!
      processed += 1

      if result
        success += 1
        # Embedding'i de güncelle (image_description dahil)
        product.update_embedding!
      else
        errors += 1
      end

      print "\rProcessed #{processed}/#{total} (#{success} success, #{errors} failed)..."

      # Rate limit için kısa bekleme
      sleep(0.5)
    rescue StandardError => e
      errors += 1
      puts "\nError processing product ##{product.id}: #{e.message}"
    end

    puts "\n\n✅ Image analysis complete!"
    puts "   Processed: #{processed}"
    puts "   Success: #{success}"
    puts "   Failed: #{errors}"
  end

  desc 'Check product image analysis status'
  task image_analysis_status: :environment do
    total = Shopify::Product.count
    with_images = Shopify::Product.where.not(images: nil).where.not(images: []).count
    analyzed = Shopify::Product.where.not(image_analyzed_at: nil).count
    pending = with_images - analyzed

    puts 'Product Image Analysis Status:'
    puts "  Total products: #{total}"
    puts "  With images: #{with_images}"
    puts "  Analyzed: #{analyzed} (#{with_images.positive? ? (analyzed.to_f / with_images * 100).round(1) : 0}%)"
    puts "  Pending: #{pending}"
  end

  # ===== COMBINED STATUS =====

  desc 'Show overall Saturn embedding status'
  task embedding_status: :environment do
    puts '=' * 50
    puts 'SATURN EMBEDDING STATUS'
    puts '=' * 50

    # FAQ Status
    puts "\n📝 FAQ Embeddings:"
    total_faqs = Saturn::AssistantResponse.count
    faqs_with_embedding = Saturn::AssistantResponse.where.not(embedding: nil).count
    puts "   Total: #{total_faqs}"
    puts "   With embedding: #{faqs_with_embedding} (#{total_faqs.positive? ? (faqs_with_embedding.to_f / total_faqs * 100).round(1) : 0}%)"

    # Document Status
    puts "\n📄 Document Chunks:"
    total_chunks = Saturn::DocumentChunk.count
    chunks_with_embedding = Saturn::DocumentChunk.where.not(embedding: nil).count
    puts "   Total chunks: #{total_chunks}"
    puts "   With embedding: #{chunks_with_embedding} (#{total_chunks.positive? ? (chunks_with_embedding.to_f / total_chunks * 100).round(1) : 0}%)"

    # Documents without chunks
    docs_without_chunks = Saturn::Document.available
                                          .where.not(content: [nil, ''])
                                          .left_joins(:chunks)
                                          .where(saturn_document_chunks: { id: nil })
                                          .count
    puts "   Documents without chunks: #{docs_without_chunks}"

    # Product Status
    puts "\n🛍️ Product Embeddings:"
    total_products = Shopify::Product.count
    products_with_embedding = Shopify::Product.where.not(embedding: nil).count
    puts "   Total products: #{total_products}"
    puts "   With embedding: #{products_with_embedding} (#{total_products.positive? ? (products_with_embedding.to_f / total_products * 100).round(1) : 0}%)"

    # Image Analysis Status
    puts "\n📷 Product Image Analysis:"
    products_with_images = Shopify::Product.where.not(images: nil).where.not(images: []).count
    products_analyzed = Shopify::Product.where.not(image_analyzed_at: nil).count
    puts "   With images: #{products_with_images}"
    puts "   Analyzed: #{products_analyzed} (#{products_with_images.positive? ? (products_analyzed.to_f / products_with_images * 100).round(1) : 0}%)"

    # Cache Status
    puts "\n💾 Embedding Cache:"
    stats = Saturn::Llm::EmbeddingService.cache_stats
    puts "   Total Requests: #{stats[:total_requests]}"
    puts "   Hit Rate: #{stats[:hit_rate_percent]}%"
    puts "   Estimated Savings: $#{stats[:estimated_savings_usd]}"

    puts "\n" + '=' * 50
  end
end

