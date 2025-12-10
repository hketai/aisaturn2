# Tek bir ürün için Jina CLIP image embedding oluşturan worker job
# NightlyImageEmbeddingJob tarafından çağrılır
module Shopify
  class ImageEmbeddingWorkerJob < ApplicationJob
    queue_as :low
    sidekiq_options retry: 5, timeout: 60

    retry_on Faraday::TooManyRequestsError, wait: :exponentially_longer, attempts: 5
    retry_on Faraday::TimeoutError, wait: 10.seconds, attempts: 3
    retry_on Net::ReadTimeout, wait: 10.seconds, attempts: 3

    def perform(product_id)
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
  end
end

