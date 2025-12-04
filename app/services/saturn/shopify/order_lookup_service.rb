# Shopify'dan real-time sipariş sorgulama servisi
# GÜVENLİK: Email VE sipariş numarası birlikte gerekli (kimlik doğrulama)
class Saturn::Shopify::OrderLookupService
  class OrderNotFoundError < StandardError; end
  class ShopifyApiError < StandardError; end

  FULFILLMENT_STATUS_TR = {
    nil => 'Hazırlanıyor',
    'fulfilled' => 'Teslim Edildi',
    'partial' => 'Kısmen Gönderildi',
    'restocked' => 'İade Edildi',
    'pending' => 'Beklemede',
    'open' => 'İşleniyor',
    'in_progress' => 'Gönderimde',
    'on_hold' => 'Beklemede',
    'scheduled' => 'Planlandı'
  }.freeze

  FINANCIAL_STATUS_TR = {
    'pending' => 'Ödeme Bekliyor',
    'authorized' => 'Onaylandı',
    'paid' => 'Ödendi',
    'partially_paid' => 'Kısmen Ödendi',
    'refunded' => 'İade Edildi',
    'partially_refunded' => 'Kısmen İade Edildi',
    'voided' => 'İptal Edildi',
    'expired' => 'Süresi Doldu'
  }.freeze

  def initialize(account:)
    @account = account
    @hook = Integrations::Hook.find_by(account: account, app_id: 'shopify')
  end

  def available?
    @hook.present? && @hook.enabled? && @hook.access_token.present?
  end

  # GÜVENLİ SİPARİŞ SORGULAMA
  # Her iki bilgi de (email + sipariş numarası) gerekli
  def lookup_order(email:, order_number:)
    return { error: 'Shopify entegrasyonu aktif değil' } unless available?
    
    # Validasyonlar
    return { error: 'Sipariş sorgulamak için email adresinizi ve sipariş numaranızı birlikte vermeniz gerekmektedir.' } if email.blank? || order_number.blank?
    return { error: 'Geçerli bir email adresi giriniz' } unless valid_email?(email)

    # Sipariş numarasını temizle
    clean_order_number = order_number.to_s.gsub(/[^0-9]/, '')
    return { error: 'Geçerli bir sipariş numarası giriniz' } if clean_order_number.blank?

    begin
      order = fetch_and_verify_order(email: email, order_number: clean_order_number)
      format_order_response(order)
    rescue OrderNotFoundError
      { error: "#{order_number} numaralı sipariş bulunamadı veya email adresi eşleşmiyor. Lütfen bilgilerinizi kontrol ediniz." }
    rescue StandardError => e
      Rails.logger.error "[SHOPIFY ORDER] Order lookup failed: #{e.message}"
      { error: "Sipariş sorgulanırken hata oluştu. Lütfen daha sonra tekrar deneyiniz." }
    end
  end

  private

  def shopify_client
    @shopify_client ||= begin
      session = ShopifyAPI::Auth::Session.new(
        shop: @hook.reference_id,
        access_token: @hook.access_token
      )
      ShopifyAPI::Clients::Rest::Admin.new(session: session)
    end
  end

  # Siparişi bul ve email ile doğrula
  def fetch_and_verify_order(email:, order_number:)
    order = fetch_order_by_number(order_number)
    
    # Email doğrulaması - siparişin email'i ile eşleşmeli
    order_email = order['email']&.downcase&.strip
    provided_email = email.downcase.strip
    
    unless order_email == provided_email
      Rails.logger.warn "[SHOPIFY ORDER] Email mismatch for order #{order_number}: provided=#{provided_email}, order=#{order_email&.first(3)}***"
      raise OrderNotFoundError, 'Email does not match'
    end
    
    order
  end

  def fetch_order_by_number(order_number)
    # Önce name ile ara (örn: #1001)
    response = shopify_client.get(
      path: 'orders.json',
      query: {
        name: order_number,
        status: 'any',
        limit: 1,
        fields: 'id,name,email,created_at,updated_at,total_price,currency,fulfillment_status,financial_status,line_items,shipping_address,fulfillments,cancelled_at,cancel_reason'
      }
    )

    orders = response.body['orders'] || []
    
    # Name ile bulunamadıysa, tüm siparişlerde ara
    if orders.empty?
      response = shopify_client.get(
        path: 'orders.json',
        query: {
          status: 'any',
          limit: 100,
          fields: 'id,name,email,order_number,created_at,updated_at,total_price,currency,fulfillment_status,financial_status,line_items,shipping_address,fulfillments,cancelled_at,cancel_reason'
        }
      )
      orders = (response.body['orders'] || []).select do |o|
        o['name']&.gsub(/[^0-9]/, '') == order_number ||
          o['order_number'].to_s == order_number
      end
    end

    raise OrderNotFoundError if orders.empty?

    orders.first
  end

  def format_order_response(order)
    {
      success: true,
      order: format_order_details(order)
    }
  end

  def format_order_details(order)
    fulfillment_status = translate_fulfillment_status(order['fulfillment_status'])
    financial_status = translate_financial_status(order['financial_status'])

    {
      order_number: order['name'],
      created_at: format_date(order['created_at']),
      total: format_price(order['total_price'], order['currency']),
      status: fulfillment_status,
      payment_status: financial_status,
      cancelled: order['cancelled_at'].present?,
      cancel_reason: order['cancel_reason'],
      items: format_line_items(order['line_items']),
      shipping_address: format_shipping_address(order['shipping_address']),
      tracking: format_tracking(order['fulfillments'])
    }
  end

  def format_line_items(items)
    return [] unless items.present?

    items.map do |item|
      {
        name: item['name'],
        quantity: item['quantity'],
        price: format_price(item['price'], 'TRY')
      }
    end
  end

  def format_shipping_address(address)
    return nil unless address.present?

    [
      address['name'],
      address['address1'],
      address['address2'],
      "#{address['city']} #{address['zip']}",
      address['country']
    ].compact.reject(&:blank?).join(', ')
  end

  def format_tracking(fulfillments)
    return nil unless fulfillments.present? && fulfillments.any?

    tracking_info = []
    fulfillments.each do |f|
      next unless f['tracking_number'].present?

      tracking_info << {
        tracking_number: f['tracking_number'],
        tracking_url: f['tracking_url'],
        company: f['tracking_company'],
        status: translate_fulfillment_status(f['status'])
      }
    end

    tracking_info.presence
  end

  def translate_fulfillment_status(status)
    FULFILLMENT_STATUS_TR[status] || status || 'Hazırlanıyor'
  end

  def translate_financial_status(status)
    FINANCIAL_STATUS_TR[status] || status || 'Beklemede'
  end

  def format_date(date_string)
    return nil unless date_string.present?

    Time.parse(date_string).strftime('%d.%m.%Y %H:%M')
  rescue StandardError
    date_string
  end

  def format_price(price, currency)
    return nil unless price.present?

    "#{price} #{currency || 'TRY'}"
  end

  def valid_email?(email)
    email.present? && email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end
end
