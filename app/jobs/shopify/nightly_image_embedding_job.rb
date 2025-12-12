# Her gece çalışarak görsel aramayı aktif eden hesaplar için image embedding güncelleyen job
# Image hash ile değişiklik kontrolü yaparak sadece görseli değişen ürünlerde embedding oluşturur
module Shopify
  class NightlyImageEmbeddingJob < ApplicationJob
    queue_as :scheduled_jobs
    sidekiq_options retry: 3, timeout: 3600 # 1 saat

    def perform
      updated_count = 0
      skipped_count = 0
      error_count = 0

      Rails.logger.info '[NIGHTLY IMAGE EMBEDDING] Starting nightly image embedding update...'

      # Sadece image_search_enabled olan hesaplar için çalıştır
      Integrations::Hook.where(app_id: 'shopify', status: :enabled).find_each do |hook|
        # Görsel arama aktif mi kontrol et
        next unless hook.settings&.dig('image_search_enabled')

        Rails.logger.info "[NIGHTLY IMAGE EMBEDDING] Processing account #{hook.account_id}"

        Product.where(account_id: hook.account_id).find_each(batch_size: 100) do |product|
          # Image hash yoksa veya boşsa hesapla
          if product.image_hash.blank?
            new_hash = product.calculate_image_hash
            if new_hash.present?
              product.update_column(:image_hash, new_hash)
            else
              skipped_count += 1
              next # Görsel yoksa skip
            end
          end

          next if product.image_hash.blank?

          # Mevcut image embedding var mı ve hash eşleşiyor mu?
          existing = ProductImageEmbedding.find_by(
            shopify_product_id: product.id,
            image_hash: product.image_hash
          )

          if existing&.embedding.present?
            skipped_count += 1
            next
          end

          # Yeni image embedding oluştur (background job ile)
          ImageEmbeddingWorkerJob.perform_later(product.id)
          updated_count += 1
        rescue StandardError => e
          Rails.logger.error "[NIGHTLY IMAGE EMBEDDING] Error processing product #{product.id}: #{e.message}"
          error_count += 1
        end
      end

      Rails.logger.info "[NIGHTLY IMAGE EMBEDDING] Completed: Queued=#{updated_count}, Skipped=#{skipped_count}, Errors=#{error_count}"
    end
  end
end

