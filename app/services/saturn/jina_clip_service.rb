# Jina AI CLIP API ile image/text embedding servisi
# jina-clip-v1 modeli hem resim hem metin için aynı embedding space kullanır
class Saturn::JinaClipService
  JINA_API_URL = 'https://api.jina.ai/v1/embeddings'.freeze
  MODEL = 'jina-clip-v1'.freeze
  EMBEDDING_DIM = 768

  def initialize
    @api_key = fetch_api_key
  end

  # Resim URL'sinden embedding oluştur
  def embed_image(image_url)
    return nil if image_url.blank? || @api_key.blank?

    response = make_request(
      input: [{ image: image_url }],
      model: MODEL
    )

    extract_embedding(response)
  rescue StandardError => e
    Rails.logger.error "[JINA CLIP] Image embedding error: #{e.message}"
    nil
  end

  # Metin için embedding oluştur (aynı space'de)
  def embed_text(text)
    return nil if text.blank? || @api_key.blank?

    response = make_request(
      input: [{ text: text }],
      model: MODEL
    )

    extract_embedding(response)
  rescue StandardError => e
    Rails.logger.error "[JINA CLIP] Text embedding error: #{e.message}"
    nil
  end

  # Birden fazla resim için batch embedding
  def embed_images_batch(image_urls)
    return [] if image_urls.blank? || @api_key.blank?

    input = image_urls.map { |url| { image: url } }
    response = make_request(input: input, model: MODEL)

    response.dig('data')&.map { |d| d['embedding'] } || []
  rescue StandardError => e
    Rails.logger.error "[JINA CLIP] Batch embedding error: #{e.message}"
    []
  end

  def api_key_present?
    @api_key.present?
  end

  private

  def fetch_api_key
    # Önce InstallationConfig'den dene
    key = InstallationConfig.find_by(name: 'JINA_AI_API_KEY')&.value
    return key if key.present?

    # ENV'den dene
    ENV.fetch('JINA_AI_API_KEY', nil)
  end

  def make_request(payload)
    uri = URI(JINA_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[JINA CLIP] API error: #{response.code} - #{response.body}"
      return nil
    end

    JSON.parse(response.body)
  end

  def extract_embedding(response)
    response&.dig('data', 0, 'embedding')
  end
end

