module Ikas
  class SyncProductsBatchJob < ApplicationJob
    queue_as :low

    sidekiq_options retry: 3, timeout: 120

    BATCH_SIZE = 50

    def perform(account_id:, hook_id:, sync_status_id:, cursor:, updated_since: nil)
      sync_status = Shopify::SyncStatus.find_by(id: sync_status_id)
      return unless sync_status && sync_status.syncing?

      hook = Integrations::Hook.find_by(id: hook_id, account_id: account_id, app_id: 'ikas')
      return unless hook&.enabled?

      begin
        api_service = Ikas::ApiService.new(hook)

        # Fetch products
        result = api_service.fetch_products(
          cursor: cursor,
          limit: BATCH_SIZE,
          updated_since: updated_since
        )

        products = result[:products]
        next_cursor = result[:next_cursor]
        has_next_page = result[:has_next_page]

        # Save products
        products.each do |product_data|
          save_product(account_id, hook_id, product_data)
        end

        # Update sync status
        sync_status.increment!(:synced_products, products.size)

        Rails.logger.info "[Ikas] Batch synced: #{products.size} products, total: #{sync_status.synced_products}/#{sync_status.total_products}"

        # Continue with next batch if there are more products
        if has_next_page && next_cursor.present?
          SyncProductsBatchJob.set(
            queue: :low,
            wait: 1.second
          ).perform_later(
            account_id: account_id,
            hook_id: hook_id,
            sync_status_id: sync_status_id,
            cursor: next_cursor,
            updated_since: updated_since
          )
        else
          # Sync complete
          sync_status.mark_completed
          Rails.logger.info "[Ikas] Sync completed: #{sync_status.synced_products} products"
          
          # Start embedding update
          ::Shopify::EmbeddingUpdateWorkerJob.perform_later(account_id, 'ikas')
        end

      rescue StandardError => e
        Rails.logger.error "[Ikas] Batch sync failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        sync_status.mark_failed(e)
        raise
      end
    end

    private

    def save_product(account_id, hook_id, product_data)
      product = Shopify::Product.find_or_initialize_by(
        account_id: account_id,
        source: 'ikas',
        external_id: product_data[:id]
      )

      product.assign_attributes(
        hook_id: hook_id,
        title: product_data[:title],
        description: product_data[:description],
        handle: product_data[:handle],
        vendor: product_data[:vendor],
        product_type: product_data[:product_type],
        min_price: product_data[:min_price],
        max_price: product_data[:max_price],
        total_inventory: product_data[:total_inventory],
        variants: product_data[:variants],
        images: product_data[:images],
        last_synced_at: Time.current
      )

      # Calculate content hash
      new_content_hash = product.calculate_content_hash
      if product.new_record? || product.content_hash != new_content_hash
        product.content_hash = new_content_hash
        product.embedding = nil # Mark for re-embedding
      end

      # Calculate image hash
      new_image_hash = product.calculate_image_hash
      if product.image_hash != new_image_hash
        product.image_hash = new_image_hash
      end

      product.save!
    rescue StandardError => e
      Rails.logger.error "[Ikas] Failed to save product #{product_data[:id]}: #{e.message}"
    end
  end
end

