class Api::V1::Accounts::Integrations::IkasController < Api::V1::Accounts::BaseController
  include Ikas::IntegrationHelper
  before_action :fetch_hook, only: [:destroy, :sync_products, :sync_status, :update_settings, :test]

  def show
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'ikas')
    if hook
      render json: {
        hook: {
          id: hook.id,
          reference_id: hook.reference_id,
          enabled: hook.enabled?,
          settings: hook.settings&.except('refresh_token') || {}
        }
      }
    else
      render json: { hook: nil }, status: :not_found
    end
  end

  # Initiates OAuth flow - returns auth URL for frontend to redirect
  def auth
    store_name = params[:store_name]

    return render json: { error: 'Mağaza adı gerekli' }, status: :unprocessable_entity if store_name.blank?

    # Validate store name format (subdomain only, no full domain)
    unless store_name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9-]*\z/)
      return render json: { error: 'Geçersiz mağaza adı formatı' }, status: :unprocessable_entity
    end

    # Generate state for CSRF protection
    state = generate_ikas_state

    # Store state in Redis with account_id (expires in 10 minutes)
    state_data = {
      account_id: Current.account.id,
      store_name: store_name,
      created_at: Time.current.to_i
    }
    Redis::Alfred.setex("ikas_oauth_state:#{state}", state_data.to_json, 600)

    # Generate OAuth URL
    auth_url = ikas_oauth_authorize_url(store_name, state)

    render json: { redirect_url: auth_url }
  rescue StandardError => e
    Rails.logger.error "[Ikas] Auth error: #{e.message}"
    render json: { error: "Yetkilendirme hatası: #{e.message}" }, status: :unprocessable_entity
  end

  def test
    # Ensure we have valid token
    access_token = ensure_valid_token(@hook)
    return render json: { error: 'Token alınamadı', success: false }, status: :unprocessable_entity unless access_token

    # Test connection
    merchant_info = test_ikas_connection(access_token)
    unless merchant_info
      return render json: { error: 'Bağlantı test edilemedi', success: false }, status: :unprocessable_entity
    end

    render json: {
      success: true,
      merchant: {
        email: merchant_info['email'],
        storefront: merchant_info['storefront']
      }
    }
  rescue StandardError => e
    render json: { error: e.message, success: false }, status: :unprocessable_entity
  end

  def destroy
    hook_id = @hook.id
    account_id = Current.account.id

    # Delete related products with source 'ikas'
    product_ids = Shopify::Product.where(account_id: account_id, source: 'ikas', hook_id: hook_id).pluck(:id)
    Shopify::ProductEmbedding.where(shopify_product_id: product_ids).delete_all
    Shopify::ProductImageEmbedding.where(shopify_product_id: product_ids).delete_all

    deleted_products_count = product_ids.count
    Shopify::Product.where(id: product_ids).delete_all

    # Delete sync status records
    Shopify::SyncStatus.where(account_id: account_id, hook_id: hook_id).delete_all

    # Delete hook
    @hook.destroy!

    Rails.logger.info "[Ikas] Integration disconnected for account #{account_id}. Deleted #{deleted_products_count} products."

    render json: {
      success: true,
      message: "İkas entegrasyonu kaldırıldı ve #{deleted_products_count} ürün silindi."
    }
  rescue StandardError => e
    Rails.logger.error "[Ikas] Error destroying integration: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_products
    # Check for active sync
    active_sync = Shopify::SyncStatus.active.find_by(
      account_id: Current.account.id,
      hook_id: @hook.id
    )

    if active_sync
      render json: {
        message: 'Sync already in progress',
        sync_status: {
          id: active_sync.id,
          status: active_sync.status,
          synced_products: active_sync.synced_products,
          total_products: active_sync.total_products,
          progress_percentage: active_sync.progress_percentage
        }
      }
      return
    end

    incremental = params[:incremental] == true || params[:incremental] == 'true'

    # Start sync job
    Ikas::SyncProductsMasterJob.perform_later(Current.account.id, @hook.id, incremental: incremental)

    sync_type = incremental ? 'incremental' : 'full'
    render json: {
      message: "Product #{sync_type} sync started",
      status: 'pending',
      sync_type: sync_type
    }
  rescue StandardError => e
    Rails.logger.error "[Ikas] Sync products failed: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_status
    sync_status = Shopify::SyncStatus.recent.find_by(
      account_id: Current.account.id,
      hook_id: @hook.id
    )

    # Get total synced products count for ikas
    total_synced_products = Shopify::Product.where(account_id: Current.account.id, source: 'ikas').count

    # Get embedding counts
    product_ids = Shopify::Product.where(account_id: Current.account.id, source: 'ikas').pluck(:id)
    total_embeddings = Shopify::ProductEmbedding.where(shopify_product_id: product_ids).count
    embedding_in_progress = total_synced_products > 0 && total_embeddings < total_synced_products

    response_data = {
      total_synced_products: total_synced_products,
      total_embeddings: total_embeddings,
      embedding_in_progress: embedding_in_progress
    }

    if sync_status
      response_data[:sync_status] = {
        id: sync_status.id,
        status: sync_status.status,
        synced_products: sync_status.synced_products,
        total_products: sync_status.total_products,
        progress_percentage: sync_status.progress_percentage,
        started_at: sync_status.started_at,
        completed_at: sync_status.completed_at,
        error_message: sync_status.error_message
      }
    else
      response_data[:sync_status] = nil
    end

    render json: response_data
  end

  def update_settings
    settings = params[:settings] || {}

    current_settings = @hook.settings || {}
    # Don't allow overwriting sensitive fields
    safe_settings = settings.to_unsafe_h.except('refresh_token', 'client_id', 'client_secret')
    new_settings = current_settings.merge(safe_settings)

    @hook.update!(settings: new_settings)

    render json: {
      success: true,
      settings: new_settings.except('refresh_token')
    }
  rescue StandardError => e
    Rails.logger.error "[Ikas] Error updating settings: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'ikas')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Entegrasyon bulunamadı' }, status: :not_found
  end

  # Ensures we have a valid access token, refreshing if needed
  def ensure_valid_token(hook)
    settings = hook.settings || {}
    token_expires_at = settings['token_expires_at']

    # Check if token is still valid (with 5 minute buffer)
    if token_expires_at.present?
      expires_at = Time.parse(token_expires_at.to_s) rescue nil
      if expires_at && expires_at > 5.minutes.from_now
        return hook.access_token
      end
    end

    # Try to refresh token
    refresh_token = settings['refresh_token']
    if refresh_token.present?
      token_response = refresh_ikas_token(refresh_token)
      if token_response && token_response['access_token']
        hook.access_token = token_response['access_token']
        hook.settings['refresh_token'] = token_response['refresh_token'] if token_response['refresh_token']
        hook.settings['token_expires_at'] = Time.current + token_response['expires_in'].to_i.seconds if token_response['expires_in']
        hook.save!
        return hook.access_token
      end
    end

    # If refresh failed, return current token (might still work)
    hook.access_token
  end
end
