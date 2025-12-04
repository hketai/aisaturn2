module Shopify
  class UpdateProductEmbeddingJob < ApplicationJob
    queue_as :low
    
    # Timeout'u artır ve retry sayısını artır
    sidekiq_options retry: 10, timeout: 120
    
    # Rate limit durumunda exponential backoff
    retry_on Faraday::TooManyRequestsError, wait: :exponentially_longer, attempts: 10
    retry_on Faraday::TimeoutError, wait: 10.seconds, attempts: 5
    retry_on Net::ReadTimeout, wait: 10.seconds, attempts: 5
    
    def perform(product_id)
      product = Product.find_by(id: product_id)
      
      unless product
        Rails.logger.warn "[EMBEDDING] Product #{product_id} not found, skipping"
        return
      end
      
      # Zaten embedding varsa skip
      if product.embedding.present?
        Rails.logger.debug "[EMBEDDING] Product #{product_id} already has embedding, skipping"
        return
      end
      
      Rails.logger.info "[EMBEDDING] Generating embedding for product #{product_id}: #{product.title}"
      product.update_embedding!
      Rails.logger.info "[EMBEDDING] Successfully generated embedding for product #{product_id}"
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "[EMBEDDING] Product #{product_id} not found"
      # Retry yapma, ürün silinmiş
    rescue StandardError => e
      Rails.logger.error "[EMBEDDING] Failed to update embedding for product #{product_id}: #{e.class} - #{e.message}"
      raise # Retry için
    end
  end
end

