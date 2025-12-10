class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders, :test]
  before_action :fetch_hook, except: [:auth, :connect, :show, :test]
  before_action :validate_contact, only: [:orders]

  def show
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'shopify')
    if hook
      render json: {
        hook: {
          id: hook.id,
          reference_id: hook.reference_id,
          enabled: hook.enabled?,
          settings: hook.settings || {}
        }
      }
    else
      render json: { hook: nil }, status: :not_found
    end
  end

  def connect
    shop_domain = params[:shop_domain]
    access_token = params[:access_token]

    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?
    return render json: { error: 'Access token is required' }, status: :unprocessable_entity if access_token.blank?

    # Validate shop domain format
    unless shop_domain.match?(/\A[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com\z/)
      return render json: { error: 'Invalid shop domain format' }, status: :unprocessable_entity
    end

    # Test the access token and get shop info
    shop_info = nil
    begin
      test_session = ShopifyAPI::Auth::Session.new(shop: shop_domain, access_token: access_token)
      test_client = ShopifyAPI::Clients::Rest::Admin.new(session: test_session)
      response = test_client.get(path: 'shop.json')
      shop_info = response.body['shop']
    rescue StandardError => e
      return render json: { error: "Invalid access token: #{e.message}" }, status: :unprocessable_entity
    end

    # Create or update the hook
    hook = Integrations::Hook.find_or_initialize_by(
      account: Current.account,
      app_id: 'shopify'
    )
    hook.reference_id = shop_domain
    hook.access_token = access_token
    hook.status = :enabled

    # Shop'un custom domain'ini settings'e kaydet
    if shop_info.present?
      custom_domain = shop_info['domain'] # Custom domain (örn: www.ovio.com.tr)
      hook.settings ||= {}
      hook.settings['custom_domain'] = custom_domain if custom_domain.present?
      hook.settings['shop_name'] = shop_info['name']
    end

    hook.save!

    render json: { hook: { id: hook.id, reference_id: hook.reference_id, enabled: hook.enabled? } }
  end

  def auth
    shop_domain = params[:shop_domain]
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    state = generate_shopify_token(Current.account.id)

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def test
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'shopify')
    return render json: { error: 'Integration not found' }, status: :not_found unless hook

    # Test connection by fetching shop info
    session = ShopifyAPI::Auth::Session.new(shop: hook.reference_id, access_token: hook.access_token)
    client = ShopifyAPI::Clients::Rest::Admin.new(session: session)
    shop_info = client.get(path: 'shop.json')

    render json: { success: true, shop: shop_info.body['shop'] }
  rescue StandardError => e
    render json: { error: e.message, success: false }, status: :unprocessable_entity
  end

  # Kaydetmeden önce credentials'ı test et
  def test_credentials
    shop_domain = params[:shop_domain]
    access_token = params[:access_token]

    return render json: { error: 'Mağaza adresi gerekli', success: false }, status: :unprocessable_entity if shop_domain.blank?
    return render json: { error: 'Erişim anahtarı gerekli', success: false }, status: :unprocessable_entity if access_token.blank?

    # Validate shop domain format
    unless shop_domain.match?(/\A[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com\z/)
      return render json: { error: 'Geçersiz mağaza adresi formatı', success: false }, status: :unprocessable_entity
    end

    # Test the access token by fetching shop info
    begin
      test_session = ShopifyAPI::Auth::Session.new(shop: shop_domain, access_token: access_token)
      test_client = ShopifyAPI::Clients::Rest::Admin.new(session: test_session)
      response = test_client.get(path: 'shop.json')
      shop_info = response.body['shop']

      render json: { 
        success: true, 
        shop: {
          name: shop_info['name'],
          domain: shop_info['domain'],
          email: shop_info['email']
        }
      }
    rescue ShopifyAPI::Errors::HttpResponseError => e
      error_message = if e.response.code == 401
                        'Erişim anahtarı geçersiz veya süresi dolmuş'
                      elsif e.response.code == 404
                        'Mağaza bulunamadı'
                      else
                        "Bağlantı hatası: #{e.message}"
                      end
      render json: { error: error_message, success: false }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { error: "Bağlantı hatası: #{e.message}", success: false }, status: :unprocessable_entity
    end
  end

  def orders
    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders(customers.first['id'])
    render json: { orders: orders }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_products
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'shopify')
    return render json: { error: 'Integration not found' }, status: :not_found unless hook
    
    # Mevcut aktif sync var mı?
    active_sync = Shopify::SyncStatus.active.find_by(
      account_id: Current.account.id,
      hook_id: hook.id
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
    
    # Incremental sync mi?
    incremental = params[:incremental] == true || params[:incremental] == 'true'
    
    # Yeni sync başlat
    Shopify::SyncProductsMasterJob.perform_later(Current.account.id, hook.id, incremental: incremental)
    
    sync_type = incremental ? 'incremental' : 'full'
    render json: { 
      message: "Product #{sync_type} sync started",
      status: 'pending',
      sync_type: sync_type
    }
  rescue StandardError => e
    Rails.logger.error "Sync products failed: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_status
    hook = Integrations::Hook.find_by(account: Current.account, app_id: 'shopify')
    return render json: { error: 'Integration not found' }, status: :not_found unless hook
    
    sync_status = Shopify::SyncStatus.recent.find_by(
      account_id: Current.account.id,
      hook_id: hook.id
    )
    
    # Get total synced products count
    total_synced_products = Shopify::Product.for_account(Current.account.id).count
    
    if sync_status
      render json: {
        sync_status: {
          id: sync_status.id,
          status: sync_status.status,
          synced_products: sync_status.synced_products,
          total_products: sync_status.total_products,
          progress_percentage: sync_status.progress_percentage,
          started_at: sync_status.started_at,
          completed_at: sync_status.completed_at,
          error_message: sync_status.error_message
        },
        total_synced_products: total_synced_products
      }
    else
      render json: { 
        sync_status: nil,
        total_synced_products: total_synced_products
      }
    end
  end

  private

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'shopify')
  end

  def fetch_customers
    query = []
    query << "email:#{contact.email}" if contact.email.present?
    query << "phone:#{contact.phone_number}" if contact.phone_number.present?

    shopify_client.get(
      path: 'customers/search.json',
      query: {
        query: query.join(' OR '),
        fields: 'id,email,phone'
      }
    ).body['customers'] || []
  end

  def fetch_orders(customer_id)
    orders = shopify_client.get(
      path: 'orders.json',
      query: {
        customer_id: customer_id,
        status: 'any',
        fields: 'id,email,created_at,total_price,currency,fulfillment_status,financial_status'
      }
    ).body['orders'] || []

    orders.map do |order|
      order.merge('admin_url' => "https://#{@hook.reference_id}/admin/orders/#{order['id']}")
    end
  end

  def setup_shopify_context
    return if client_id.blank? || client_secret.blank?

    ShopifyAPI::Context.setup(
      api_key: client_id,
      api_secret_key: client_secret,
      api_version: '2025-01'.freeze,
      scope: REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end

  def shopify_session
    ShopifyAPI::Auth::Session.new(shop: @hook.reference_id, access_token: @hook.access_token)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' },
           status: :unprocessable_entity
  end
end
