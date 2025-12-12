# Tek bir ürün için embedding oluşturan worker job
# NightlyEmbeddingUpdateJob tarafından çağrılır
module Shopify
  class EmbeddingUpdateWorkerJob < ApplicationJob
    queue_as :low
    sidekiq_options retry: 5, timeout: 60

    retry_on Faraday::TooManyRequestsError, wait: :exponentially_longer, attempts: 5
    retry_on Faraday::TimeoutError, wait: 10.seconds, attempts: 3
    retry_on Net::ReadTimeout, wait: 10.seconds, attempts: 3

    def perform(product_id)
      product = Product.find_by(id: product_id)
      return unless product

      # Content hash yoksa hesapla
      if product.content_hash.blank?
        new_hash = product.calculate_content_hash
        ActiveRecord::Base.connection.execute(
          "UPDATE shopify_products SET content_hash = '#{new_hash}' WHERE id = #{product.id}"
        )
        product.content_hash = new_hash
      end

      # Zaten bu hash için embedding varsa skip
      existing = ProductEmbedding.find_by(
        shopify_product_id: product.id,
        content_hash: product.content_hash
      )
      if existing&.embedding.present?
        Rails.logger.debug "[EMBEDDING] Product #{product_id} already has embedding for current hash"
        return
      end

      # Embedding oluştur
      text_content = [product.title, product.description, product.variant_titles_text].compact.join(' ')
      if text_content.length < 3
        Rails.logger.warn "[EMBEDDING] Product #{product_id} text too short, skipping"
        return
      end

      embedding_service = Saturn::Llm::EmbeddingService.new
      embedding_vector = embedding_service.create_vector_embedding(text_content)

      if embedding_vector.blank?
        Rails.logger.error "[EMBEDDING] Product #{product_id}: Empty embedding returned"
        return
      end

      # Eski embedding'leri sil (farklı hash ile)
      ProductEmbedding.where(shopify_product_id: product.id)
                      .where.not(content_hash: product.content_hash)
                      .delete_all

      # Yeni embedding kaydet
      ProductEmbedding.create!(
        shopify_product_id: product.id,
        account_id: product.account_id,
        content_hash: product.content_hash,
        embedding: embedding_vector,
        embedded_at: Time.current
      )

      Rails.logger.info "[EMBEDDING] Product #{product_id} embedded successfully"
    rescue ActiveRecord::RecordNotUnique
      # Başka bir worker aynı anda oluşturmuş olabilir
      Rails.logger.debug "[EMBEDDING] Product #{product_id} embedding already created by another worker"
    rescue StandardError => e
      Rails.logger.error "[EMBEDDING] Failed to update embedding for product #{product_id}: #{e.class} - #{e.message}"
      raise # Retry için
    end
  end
end

