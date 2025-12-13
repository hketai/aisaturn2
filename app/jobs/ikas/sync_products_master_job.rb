module Ikas
  class SyncProductsMasterJob < ApplicationJob
    queue_as :medium
    
    sidekiq_options retry: 3, timeout: 300

    def perform(account_id, hook_id, incremental: false)
      hook = Integrations::Hook.find_by(id: hook_id, account_id: account_id, app_id: 'ikas')
      return unless hook&.enabled?

      # Check for active sync
      active_sync = Shopify::SyncStatus.active.find_by(account_id: account_id, hook_id: hook_id)
      if active_sync
        Rails.logger.info "[Ikas] Sync already in progress for account #{account_id}, hook #{hook_id}"
        return
      end

      # Find last completed sync (for incremental sync)
      last_completed_sync = Shopify::SyncStatus.where(
        account_id: account_id,
        hook_id: hook_id,
        status: :completed
      ).order(completed_at: :desc).first

      is_incremental = incremental && last_completed_sync.present?
      updated_since = is_incremental ? last_completed_sync.completed_at : nil

      # Create new sync status
      sync_status = Shopify::SyncStatus.create!(
        account_id: account_id,
        hook_id: hook_id,
        status: :pending,
        sync_type: is_incremental ? :incremental : :full,
        started_at: Time.current
      )

      begin
        # Get Ikas API client
        api_service = Ikas::ApiService.new(hook)
        
        # Fetch product count
        total_products = api_service.fetch_product_count(updated_since: updated_since)

        sync_status.update!(
          total_products: total_products,
          status: :syncing
        )

        # No products to sync
        if total_products.zero?
          sync_status.mark_completed
          Rails.logger.info "[Ikas] No products to sync (incremental: #{is_incremental})"
          return
        end

        Rails.logger.info "[Ikas] Starting #{is_incremental ? 'incremental' : 'full'} sync: #{total_products} products"

        # Start first batch
        SyncProductsBatchJob.set(
          queue: :low
        ).perform_later(
          account_id: account_id,
          hook_id: hook_id,
          sync_status_id: sync_status.id,
          cursor: nil,
          updated_since: updated_since&.iso8601
        )

        Rails.logger.info "[Ikas] Started sync for sync #{sync_status.id}"

      rescue StandardError => e
        Rails.logger.error "[Ikas] Sync master job failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        sync_status.mark_failed(e)
        raise
      end
    end
  end
end

