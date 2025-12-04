module Shopify
  class SyncProductsMasterJob < ApplicationJob
    queue_as :medium
    
    # Timeout'u uzat (çok fazla ürün olabilir)
    sidekiq_options retry: 3, timeout: 300 # 5 dakika
    
    def perform(account_id, hook_id, incremental: false)
      hook = Integrations::Hook.find_by(id: hook_id, account_id: account_id)
      return unless hook&.enabled?
      
      # Mevcut aktif sync var mı kontrol et
      active_sync = SyncStatus.active.find_by(account_id: account_id, hook_id: hook_id)
      if active_sync
        Rails.logger.info "Sync already in progress for account #{account_id}, hook #{hook_id}"
        return
      end
      
      # Son başarılı sync'i bul (incremental sync için)
      last_completed_sync = SyncStatus.where(
        account_id: account_id,
        hook_id: hook_id,
        status: :completed
      ).order(completed_at: :desc).first
      
      # İlk sync mi yoksa incremental mı?
      is_incremental = incremental && last_completed_sync.present?
      updated_since = is_incremental ? last_completed_sync.completed_at : nil
      
      # Yeni sync status oluştur
      sync_status = SyncStatus.create!(
        account_id: account_id,
        hook_id: hook_id,
        status: :pending,
        sync_type: is_incremental ? :incremental : :full,
        started_at: Time.current
      )
      
      begin
        # Shopify API'den toplam ürün sayısını öğren
        session = ShopifyAPI::Auth::Session.new(
          shop: hook.reference_id,
          access_token: hook.access_token
        )
        client = ShopifyAPI::Clients::Rest::Admin.new(session: session)
        
        # Count endpoint'i ile toplam sayıyı al
        count_params = {}
        count_params[:updated_at_min] = updated_since.iso8601 if updated_since.present?
        
        count_response = client.get(path: 'products/count.json', query: count_params)
        total_products = count_response.body['count'] || 0
        
        sync_status.update!(
          total_products: total_products,
          status: :syncing
        )
        
        # Ürün yoksa direkt tamamla
        if total_products.zero?
          sync_status.mark_completed
          Rails.logger.info "No products to sync (incremental: #{is_incremental})"
          return
        end
        
        # Cursor-based pagination ile ürünleri çek
        # İlk batch'i başlat, diğerleri zincir şeklinde devam edecek
        batch_size = 250
        
        Rails.logger.info "Starting #{is_incremental ? 'incremental' : 'full'} sync: #{total_products} products"
        
        # İlk batch'i başlat (page_info yok)
        SyncProductsBatchJob.set(
          queue: :low
        ).perform_later(
          account_id: account_id,
          hook_id: hook_id,
          sync_status_id: sync_status.id,
          page_info: nil,
          batch_size: batch_size,
          updated_since: updated_since&.iso8601
        )
        
        Rails.logger.info "Started #{is_incremental ? 'incremental' : 'full'} sync for sync #{sync_status.id}"
        
      rescue StandardError => e
        Rails.logger.error "Sync master job failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        sync_status.mark_failed(e)
        raise
      end
    end
  end
end

