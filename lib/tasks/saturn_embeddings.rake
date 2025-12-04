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

    # Cache Status
    puts "\n💾 Embedding Cache:"
    stats = Saturn::Llm::EmbeddingService.cache_stats
    puts "   Total Requests: #{stats[:total_requests]}"
    puts "   Hit Rate: #{stats[:hit_rate_percent]}%"
    puts "   Estimated Savings: $#{stats[:estimated_savings_usd]}"

    puts "\n" + '=' * 50
  end
end

