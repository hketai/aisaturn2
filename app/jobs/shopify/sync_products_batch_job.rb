module Shopify
  class SyncProductsBatchJob < ApplicationJob
    queue_as :low
    
    # Her batch için kısa timeout (250 ürün)
    sidekiq_options retry: 5, timeout: 60 # 1 dakika
    
    retry_on ShopifyAPI::Errors::HttpResponseError, 
             wait: :exponentially_longer, 
             attempts: 5
    
    retry_on Net::ReadTimeout, 
             wait: 5.seconds, 
             attempts: 3
    
    def perform(account_id:, hook_id:, sync_status_id:, page_info: nil, batch_size: 250, updated_since: nil)
      hook = Integrations::Hook.find_by(id: hook_id, account_id: account_id)
      sync_status = SyncStatus.find(sync_status_id)
      
      return if sync_status.failed? || sync_status.cancelled?
      return unless hook&.enabled?
      
      # Shopify API'den ürünleri çek
      session = ShopifyAPI::Auth::Session.new(
        shop: hook.reference_id,
        access_token: hook.access_token
      )
      client = ShopifyAPI::Clients::Rest::Admin.new(session: session, api_version: '2024-10')
      
      # Cursor-based pagination ile ürünleri çek
      query_params = {
        limit: batch_size,
        fields: 'id,title,body_html,handle,vendor,product_type,variants,images,updated_at'
      }
      query_params[:page_info] = page_info if page_info.present?
      
      # Sadece güncellenmiş ürünleri çek (incremental sync için)
      # Not: page_info varsa updated_at_min kullanılmaz (Shopify API kısıtlaması)
      if updated_since.present? && page_info.blank?
        query_params[:updated_at_min] = updated_since
      end
      
      response = client.get(
        path: 'products.json',
        query: query_params
      )
      
      products = response.body['products'] || []
      
      if products.empty?
        Rails.logger.info "No more products to sync"
        # Tüm ürünler çekildi, sync'i tamamla
        if sync_status.syncing?
          sync_status.mark_completed
          Rails.logger.info "Sync #{sync_status_id} completed"
        end
        return
      end
      
      # Her ürünü DB'ye kaydet
      synced_count = 0
      products.each do |shopify_product|
        begin
          product = Product.find_or_initialize_by(
            account_id: account_id,
            shopify_product_id: shopify_product['id']
          )
          
          product.assign_attributes(
            hook_id: hook_id,
            title: shopify_product['title'],
            description: clean_html(shopify_product['body_html']),
            handle: shopify_product['handle'],
            vendor: shopify_product['vendor'],
            product_type: shopify_product['product_type'],
            variants: shopify_product['variants'] || [],
            images: shopify_product['images'] || [],
            min_price: calculate_min_price(shopify_product['variants']),
            max_price: calculate_max_price(shopify_product['variants']),
            total_inventory: calculate_total_inventory(shopify_product['variants']),
            last_synced_at: Time.current
          )

          # Content ve image hash'lerini hesapla (embedding için değişiklik takibi)
          product.content_hash = product.calculate_content_hash
          product.image_hash = product.calculate_image_hash

          product.save!
          synced_count += 1

          # NOT: Embedding artık gece job'ı ile yapılıyor (NightlyEmbeddingUpdateJob)
          # Bu sayede sync hızlı tamamlanır ve embedding maliyeti optimize edilir
          
        rescue StandardError => e
          Rails.logger.error "Failed to save product #{shopify_product['id']}: #{e.message}"
          # Devam et, bir ürün hatası tüm sync'i durdurmasın
        end
      end
      
      # Progress güncelle
      current_synced = sync_status.synced_products + synced_count
      
      Rails.logger.info "[SHOPIFY SYNC] Before update: synced=#{sync_status.synced_products}, status=#{sync_status.status}"
      Rails.logger.info "[SHOPIFY SYNC] Updating progress: #{current_synced}/#{sync_status.total_products}"
      
      begin
        sync_status.update_progress(
          synced: current_synced,
          total: sync_status.total_products
        )
        sync_status.reload
        Rails.logger.info "[SHOPIFY SYNC] After update: synced=#{sync_status.synced_products}, status=#{sync_status.status}"
      rescue => e
        Rails.logger.error "[SHOPIFY SYNC] Failed to update progress: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
      end
      
      Rails.logger.info "Batch completed: #{synced_count} products synced (#{current_synced}/#{sync_status.total_products})"
      
      # Link header'dan next page_info'yu al
      link_header = response.headers['link']
      next_page_info = extract_next_page_info(link_header)
      
      if next_page_info.present? && current_synced < sync_status.total_products
        # Bir sonraki batch'i başlat
        SyncProductsBatchJob.set(
          queue: :low,
          wait: 1.second # Rate limiting
        ).perform_later(
          account_id: account_id,
          hook_id: hook_id,
          sync_status_id: sync_status_id,
          page_info: next_page_info,
          batch_size: batch_size,
          updated_since: updated_since
        )
        Rails.logger.info "Next batch scheduled with page_info"
      else
        # Tüm ürünler çekildi
        sync_status.mark_completed
        Rails.logger.info "Sync #{sync_status_id} completed: #{current_synced} products (type: #{sync_status.sync_type})"
        
        # Sync tamamlandıktan hemen sonra embedding job'larını başlat
        start_embedding_jobs(account_id, hook_id)
      end
      
    rescue ShopifyAPI::Errors::HttpResponseError => e
      # Rate limit veya API hatası
      Rails.logger.error "Shopify API error: #{e.message}"
      Rails.logger.error "Response body: #{e.response&.body}"
      
      if e.code == 429 # Rate limit
        # Exponential backoff ile retry
        raise
      else
        # Diğer hatalar için sync'i işaretle
        sync_status.mark_failed(e)
        raise
      end
      
    rescue StandardError => e
      Rails.logger.error "Batch job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
    
    private
    
    def extract_next_page_info(link_header)
      return nil if link_header.blank?
      
      # Link header can be a string or array
      link_str = link_header.is_a?(Array) ? link_header.first : link_header
      return nil if link_str.blank?
      
      # Link header format: <https://shop.myshopify.com/admin/api/2024-01/products.json?page_info=xxx>; rel=\"next\"
      # Note: Shopify returns escaped quotes in array format
      links = link_str.split(',')
      next_link = links.find { |link| link.include?('next') && link.include?('rel=') }
      return nil unless next_link
      
      # Extract page_info parameter from URL
      match = next_link.match(/page_info=([^&>\s]+)/)
      match ? match[1] : nil
    end
    
    def clean_html(html)
      return nil if html.blank?
      # HTML'den text çıkar (basit)
      ActionController::Base.helpers.strip_tags(html)
    end
    
    def calculate_min_price(variants)
      return 0 if variants.blank?
      variants.map { |v| v['price'].to_f }.min || 0
    end
    
    def calculate_max_price(variants)
      return 0 if variants.blank?
      variants.map { |v| v['price'].to_f }.max || 0
    end
    
    def calculate_total_inventory(variants)
      return 0 if variants.blank?
      variants.sum { |v| v['inventory_quantity'].to_i || 0 }
    end

    def start_embedding_jobs(account_id, hook_id)
      Rails.logger.info "[EMBEDDING] Starting embedding jobs for account #{account_id}"
      
      # Embedding'i olmayan veya content_hash'i değişmiş ürünleri bul
      products_to_embed = Shopify::Product
        .where(account_id: account_id)
        .where(embedding: nil)
        .or(Shopify::Product.where(account_id: account_id).where(content_hash: nil))
      
      count = 0
      products_to_embed.find_each(batch_size: 100) do |product|
        # Her ürün için embedding job'u kuyruğa ekle
        EmbeddingUpdateWorkerJob.set(queue: :low).perform_later(product.id)
        count += 1
      end
      
      Rails.logger.info "[EMBEDDING] Queued #{count} products for embedding"
    end
  end
end

