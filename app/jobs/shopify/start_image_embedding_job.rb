# Gelişmiş Görsel Arama aktif edildiğinde image embedding'leri başlatır
module Shopify
  class StartImageEmbeddingJob < ApplicationJob
    queue_as :medium
    sidekiq_options retry: 3, timeout: 300

    def perform(account_id:, hook_id:)
      Rails.logger.info "[IMAGE EMBEDDING] Starting for account #{account_id}"

      # Image hash'i olmayan veya image embedding'i olmayan ürünleri bul
      products = Shopify::Product.where(account_id: account_id, hook_id: hook_id)
      
      queued_count = 0
      products.find_each(batch_size: 100) do |product|
        # Görsel yoksa skip
        next if product.images.blank?
        
        # Image hash hesapla (yoksa)
        if product.image_hash.blank?
          new_hash = product.calculate_image_hash
          next if new_hash.blank?
          
          product.update_column(:image_hash, new_hash) rescue nil
          product.image_hash = new_hash
        end
        
        # Bu hash için embedding zaten varsa skip
        existing = Shopify::ProductImageEmbedding.find_by(
          shopify_product_id: product.id,
          image_hash: product.image_hash
        )
        next if existing&.embedding.present?
        
        # Image embedding job'ını kuyruğa ekle (rate limiting için delay)
        delay_seconds = (queued_count / 10) * 2 # Her 10 üründe 2 saniye bekle
        Shopify::ImageEmbeddingWorkerJob.set(queue: :low, wait: delay_seconds.seconds).perform_later(product.id)
        queued_count += 1
      end
      
      Rails.logger.info "[IMAGE EMBEDDING] Queued #{queued_count} products for account #{account_id}"
    end
  end
end

