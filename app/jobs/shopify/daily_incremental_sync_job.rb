module Shopify
  class DailyIncrementalSyncJob < ApplicationJob
    queue_as :scheduled_jobs
    
    def perform
      # Shopify hook'u olan tüm hesapları bul
      Integrations::Hook.where(app_id: 'shopify', status: :enabled).find_each do |hook|
        # Daha önce sync yapılmış mı kontrol et
        has_previous_sync = SyncStatus.exists?(
          account_id: hook.account_id,
          hook_id: hook.id,
          status: :completed
        )
        
        if has_previous_sync
          # Incremental sync başlat (sadece güncellenmiş ürünler)
          Rails.logger.info "Starting incremental sync for account #{hook.account_id}"
          SyncProductsMasterJob.perform_later(hook.account_id, hook.id, incremental: true)
        else
          # İlk kez sync yapılacak, full sync
          Rails.logger.info "Starting full sync for account #{hook.account_id} (first time)"
          SyncProductsMasterJob.perform_later(hook.account_id, hook.id, incremental: false)
        end
      end
    end
  end
end

