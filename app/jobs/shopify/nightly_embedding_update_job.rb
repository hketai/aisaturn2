# Her gece çalışarak değişen ürünlerin embedding'lerini güncelleyen job
# Content hash ile değişiklik kontrolü yaparak sadece gerçekten değişen ürünlerde embedding oluşturur
module Shopify
  class NightlyEmbeddingUpdateJob < ApplicationJob
    queue_as :scheduled_jobs
    sidekiq_options retry: 3, timeout: 3600 # 1 saat

    def perform
      updated_count = 0
      skipped_count = 0
      error_count = 0

      Rails.logger.info '[NIGHTLY EMBEDDING] Starting nightly embedding update...'

      # Tüm aktif Shopify entegrasyonları için
      Integrations::Hook.where(app_id: 'shopify', status: :enabled).find_each do |hook|
        Rails.logger.info "[NIGHTLY EMBEDDING] Processing account #{hook.account_id}"

        Product.where(account_id: hook.account_id).find_each(batch_size: 100) do |product|
          # Content hash yoksa hesapla
          if product.content_hash.blank?
            product.update_column(:content_hash, product.calculate_content_hash)
          end

          # Mevcut embedding var mı ve hash eşleşiyor mu?
          existing = ProductEmbedding.find_by(
            shopify_product_id: product.id,
            content_hash: product.content_hash
          )

          if existing&.embedding.present?
            skipped_count += 1
            next
          end

          # Yeni embedding oluştur (background job ile)
          EmbeddingUpdateWorkerJob.perform_later(product.id)
          updated_count += 1
        rescue StandardError => e
          Rails.logger.error "[NIGHTLY EMBEDDING] Error processing product #{product.id}: #{e.message}"
          error_count += 1
        end
      end

      Rails.logger.info "[NIGHTLY EMBEDDING] Completed: Queued=#{updated_count}, Skipped=#{skipped_count}, Errors=#{error_count}"
    end
  end
end

