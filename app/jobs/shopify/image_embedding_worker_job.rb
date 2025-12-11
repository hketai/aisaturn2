# Tek bir ürün için CLIP image embedding oluşturan worker job
# NightlyImageEmbeddingJob tarafından çağrılır
module Shopify
  class ImageEmbeddingWorkerJob < ApplicationJob
    queue_as :image_embedding
    sidekiq_options retry: 5, timeout: 300

    # Custom exception for CLIP service unavailable
    class ClipServiceUnavailable < StandardError; end

    retry_on Faraday::TooManyRequestsError, wait: :exponentially_longer, attempts: 5
    retry_on Faraday::TimeoutError, wait: 30.seconds, attempts: 5
    retry_on Net::ReadTimeout, wait: 30.seconds, attempts: 5
    retry_on Net::OpenTimeout, wait: 30.seconds, attempts: 5
    retry_on Saturn::JinaClipService::RateLimitError, wait: 30.seconds, attempts: 10
    retry_on ClipServiceUnavailable, wait: 60.seconds, attempts: 10

    def perform(product_id)
      # CLIP servisi çalışıyor mu kontrol et
      unless clip_service_healthy?
        Rails.logger.warn "[IMAGE EMBEDDING] CLIP service unavailable, retrying later"
        raise ClipServiceUnavailable, "CLIP service is not responding"
      end

      product = Product.find_by(id: product_id)
      return unless product

      # Görsel URL'si var mı?
      image_url = product.first_image_url
      unless image_url.present?
        Rails.logger.debug "[IMAGE EMBEDDING] Product #{product_id} has no image, skipping"
        return
      end

      # Image hash yoksa hesapla
      if product.image_hash.blank?
        new_hash = product.calculate_image_hash
        return if new_hash.blank?

        product.update_column(:image_hash, new_hash)
      end

      # Zaten bu hash için embedding varsa skip
      existing = ProductImageEmbedding.find_by(
        shopify_product_id: product.id,
        image_hash: product.image_hash
      )
      if existing&.embedding.present?
        Rails.logger.debug "[IMAGE EMBEDDING] Product #{product_id} already has image embedding for current hash"
        return
      end

      # Jina CLIP ile image embedding oluştur
      clip_service = Saturn::JinaClipService.new
      embedding_vector = clip_service.embed_image(image_url)

      if embedding_vector.blank?
        Rails.logger.error "[IMAGE EMBEDDING] Product #{product_id}: Empty image embedding returned"
        return
      end

      # Eski image embedding'leri sil (farklı hash ile)
      ProductImageEmbedding.where(shopify_product_id: product.id)
                           .where.not(image_hash: product.image_hash)
                           .delete_all

      # Yeni image embedding kaydet
      ProductImageEmbedding.create!(
        shopify_product_id: product.id,
        account_id: product.account_id,
        image_hash: product.image_hash,
        embedding: embedding_vector,
        embedded_at: Time.current
      )

      Rails.logger.info "[IMAGE EMBEDDING] Product #{product_id} image embedded successfully"
    rescue ActiveRecord::RecordNotUnique
      # Başka bir worker aynı anda oluşturmuş olabilir
      Rails.logger.debug "[IMAGE EMBEDDING] Product #{product_id} image embedding already created by another worker"
    rescue StandardError => e
      Rails.logger.error "[IMAGE EMBEDDING] Failed to update image embedding for product #{product_id}: #{e.class} - #{e.message}"
      raise # Retry için
    end

    private

    def clip_service_healthy?
      clip_service = Saturn::JinaClipService.new
      return false unless clip_service.api_key_present?

      url = clip_service.send(:fetch_api_url).gsub('/v1/embeddings', '/health')
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5
      
      response = http.get(uri.path.presence || '/health')
      response.is_a?(Net::HTTPSuccess)
    rescue StandardError => e
      Rails.logger.warn "[IMAGE EMBEDDING] CLIP health check failed: #{e.message}"
      false
    end
  end
end

