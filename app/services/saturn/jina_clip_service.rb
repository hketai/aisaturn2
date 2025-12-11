# Self-hosted CLIP API ile image/text embedding servisi
# clip-ViT-L-14 modeli kullanır (768 dimension)
class Saturn::JinaClipService
  EMBEDDING_DIM = 768 # clip-ViT-L-14 uses 768 dimensions

  # Custom exception for rate limiting
  class RateLimitError < StandardError; end

  def initialize
    @api_key = fetch_api_key
    @api_url = fetch_api_url
  end

  # Resim URL'sinden embedding oluştur
  def embed_image(image_url)
    return nil if image_url.blank? || @api_key.blank?

    response = make_request(
      input: [{ url: image_url }]
    )

    extract_embedding(response)
  rescue StandardError => e
    Rails.logger.error "[CLIP] Image embedding error: #{e.message}"
    nil
  end

  # Metin için embedding oluştur (aynı space'de)
  def embed_text(text)
    return nil if text.blank? || @api_key.blank?

    response = make_request(
      input: [text]
    )

    extract_embedding(response)
  rescue StandardError => e
    Rails.logger.error "[CLIP] Text embedding error: #{e.message}"
    nil
  end

  # Birden fazla resim için batch embedding
  def embed_images_batch(image_urls)
    return [] if image_urls.blank? || @api_key.blank?

    input = image_urls.map { |url| { url: url } }
    response = make_request(input: input)

    response&.dig('data')&.map { |d| d['embedding'] } || []
  rescue StandardError => e
    Rails.logger.error "[CLIP] Batch embedding error: #{e.message}"
    []
  end

  def api_key_present?
    @api_key.present?
  end

  private

  def fetch_api_key
    # InstallationConfig'den al
    key = InstallationConfig.find_by(name: 'CLIP_API_KEY')&.value
    return key if key.present?

    # Fallback: JINA_AI_API_KEY (geriye uyumluluk)
    key = InstallationConfig.find_by(name: 'JINA_AI_API_KEY')&.value
    return key if key.present?

    # ENV'den dene
    ENV.fetch('CLIP_API_KEY', nil)
  end

  def fetch_api_url
    # InstallationConfig'den al
    url = InstallationConfig.find_by(name: 'CLIP_API_URL')&.value
    return url if url.present?

    # ENV'den dene
    ENV.fetch('CLIP_API_URL', 'http://209.38.193.3:5000/v1/embeddings')
  end

  def make_request(payload)
    uri = URI(@api_url)
    
    # HTTP veya HTTPS
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 120
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri.path.presence || '/v1/embeddings')
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[CLIP] API error: #{response.code} - #{response.body}"

      # Rate limit hatası için exception fırlat (retry için)
      if response.code.to_i == 429
        raise RateLimitError, 'CLIP API rate limit exceeded'
      end

      return nil
    end

    JSON.parse(response.body)
  end

  def extract_embedding(response)
    response&.dig('data', 0, 'embedding')
  end
end
