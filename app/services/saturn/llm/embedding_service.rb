require 'openai'
require 'digest'

class Saturn::Llm::EmbeddingService < Saturn::Llm::BaseOpenAiService
  class EmbeddingsError < StandardError; end

  # Cache configuration
  CACHE_NAMESPACE = 'saturn_embeddings'.freeze
  CACHE_EXPIRY = 7.days # Embedding'ler 7 gün cache'de kalır
  STATS_KEY = 'saturn_embedding_stats'.freeze

  def self.embedding_model
    @embedding_model ||= fetch_embedding_model_config
  end

  def create_vector_embedding(text_content, model: self.class.embedding_model, use_cache: true)
    return create_embedding_without_cache(text_content, model) unless use_cache

    cache_key = generate_cache_key(text_content, model)
    
    # Cache'den kontrol et
    cached_embedding = fetch_from_cache(cache_key)
    if cached_embedding
      increment_stats(:cache_hits)
      Rails.logger.debug "[EMBEDDING CACHE] HIT: #{cache_key[0..20]}..."
      
      # Cache hit tracking
      track_embedding_usage(nil, model, 0, cache_hit: true)
      
      return cached_embedding
    end

    # Cache'de yoksa API'den al
    increment_stats(:cache_misses)
    Rails.logger.debug "[EMBEDDING CACHE] MISS: #{cache_key[0..20]}..."
    
    embedding = create_embedding_without_cache(text_content, model)
    
    # Cache'e kaydet
    store_in_cache(cache_key, embedding)
    increment_stats(:api_calls)
    
    embedding
  end

  # Cache kullanmadan doğrudan API çağrısı (SSS/Döküman embedding'leri için)
  def create_embedding_without_cache(text_content, model = self.class.embedding_model)
    start_time = Time.current
    embedding_params = build_embedding_params(text_content, model)
    api_response = call_embedding_api(embedding_params)
    response_time = Time.current - start_time
    
    # API Usage Tracking
    track_embedding_usage(api_response, model, response_time, cache_hit: false)
    
    extract_embedding_from_response(api_response)
  rescue StandardError => e
    track_embedding_error(model, e)
    handle_embedding_error(e)
    raise EmbeddingsError, "Saturn embedding creation failed: #{e.message}"
  end

  # Cache istatistiklerini getir
  def self.cache_stats
    stats = Rails.cache.read(STATS_KEY) || { cache_hits: 0, cache_misses: 0, api_calls: 0 }
    
    total_requests = stats[:cache_hits] + stats[:cache_misses]
    hit_rate = total_requests.positive? ? (stats[:cache_hits].to_f / total_requests * 100).round(2) : 0
    
    stats.merge(
      total_requests: total_requests,
      hit_rate_percent: hit_rate,
      estimated_savings_usd: (stats[:cache_hits] * 0.0001).round(4) # ~1000 token per query
    )
  end

  # Cache istatistiklerini sıfırla
  def self.reset_stats
    Rails.cache.delete(STATS_KEY)
  end

  # Tüm embedding cache'ini temizle
  def self.clear_cache
    # Redis kullanıyorsa pattern ile sil
    if Rails.cache.respond_to?(:redis)
      keys = Rails.cache.redis.keys("#{Rails.cache.options[:namespace]}:#{CACHE_NAMESPACE}:*")
      Rails.cache.redis.del(*keys) if keys.any?
    end
    reset_stats
    Rails.logger.info "[EMBEDDING CACHE] All cache cleared"
  end

  private

  def self.fetch_embedding_model_config
    config_value = InstallationConfig.find_by(name: 'SATURN_EMBEDDING_MODEL')&.value
    config_value.presence || OpenAiConstants::DEFAULT_EMBEDDING_MODEL
  end

  def generate_cache_key(text_content, model)
    # Text'i normalize et ve hash'le
    normalized_text = text_content.to_s.downcase.strip.gsub(/\s+/, ' ')
    text_hash = Digest::SHA256.hexdigest(normalized_text)
    
    "#{CACHE_NAMESPACE}:#{model}:#{text_hash}"
  end

  def fetch_from_cache(cache_key)
    Rails.cache.read(cache_key)
  end

  def store_in_cache(cache_key, embedding)
    Rails.cache.write(cache_key, embedding, expires_in: CACHE_EXPIRY)
  end

  def increment_stats(stat_key)
    stats = Rails.cache.read(STATS_KEY) || { cache_hits: 0, cache_misses: 0, api_calls: 0 }
    stats[stat_key] = (stats[stat_key] || 0) + 1
    Rails.cache.write(STATS_KEY, stats)
  rescue StandardError => e
    Rails.logger.warn "[EMBEDDING CACHE] Stats update failed: #{e.message}"
  end

  def build_embedding_params(text_content, model)
    {
      model: model,
      input: text_content
    }
  end

  def call_embedding_api(params)
    @client.embeddings(parameters: params)
  end

  def extract_embedding_from_response(api_response)
    api_response.dig('data', 0, 'embedding')
  end

  def handle_embedding_error(error)
    Rails.logger.error("Saturn embedding error: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if Rails.env.development?
  end

  # API Usage Tracking Methods
  def track_embedding_usage(api_response, model, response_time, cache_hit: false)
    return unless defined?(Saturn::ApiUsageTrackerService)

    usage = api_response&.dig('usage') || {}
    
    Saturn::ApiUsageTrackerService.track_embedding(
      account_id: tracking_account&.id || Current.account&.id,
      saturn_assistant_id: tracking_assistant&.id,
      model: model,
      input_tokens: usage['total_tokens'] || 0,
      output_tokens: 0,
      response_time: response_time.to_f.round(3),
      cache_hit: cache_hit
    )
  rescue StandardError => e
    Rails.logger.error "[API TRACKING] Failed to track embedding usage: #{e.message}"
  end

  def track_embedding_error(model, error)
    return unless defined?(Saturn::ApiUsageTrackerService)

    error_type = case error
                 when OpenAI::Error then 'openai_error'
                 when Faraday::TimeoutError then 'timeout'
                 when Faraday::ConnectionFailed then 'connection_failed'
                 else 'unknown'
                 end

    Saturn::ApiUsageTrackerService.track_error(
      api_type: 'embedding',
      account_id: tracking_account&.id || Current.account&.id,
      saturn_assistant_id: tracking_assistant&.id,
      model: model,
      error_type: error_type
    )
  rescue StandardError => e
    Rails.logger.error "[API TRACKING] Failed to track embedding error: #{e.message}"
  end
end
