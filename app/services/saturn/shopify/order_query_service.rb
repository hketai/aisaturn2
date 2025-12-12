# Shopify siparis sorgulama ve dogrulama servisi
# AI siparis sorgulama akisinda kullanilir
class Saturn::Shopify::OrderQueryService
  ORDER_NUMBER_REGEX = /(?:sipari[sş]|order|no|#)?[:\s#]*(\d{4,})/i
  EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/i

  def initialize(account:)
    @account = account
  end

  def available?
    hook.present? && hook.enabled?
  end

  # Mesaj iceriginden siparis numarasi ve email cikar
  def extract_order_info(message_content)
    return { order_number: nil, email: nil } if message_content.blank?

    order_number = extract_order_number(message_content)
    email = extract_email(message_content)

    { order_number: order_number, email: email }
  end

  # Siparis numarasi + email ile dogrulama yap
  def verify_order(order_number:, email:)
    return { verified: false, error: :not_available } unless available?
    return { verified: false, error: :missing_params } if order_number.blank? || email.blank?

    order = fetch_order_by_number(order_number)
    return { verified: false, error: :not_found } unless order

    if order['email']&.downcase == email.downcase
      { verified: true, order: order }
    else
      { verified: false, error: :email_mismatch }
    end
  rescue StandardError => e
    Rails.logger.error "[ORDER QUERY] Verification failed: #{e.message}"
    { verified: false, error: :api_error }
  end

  # Dogrulama sonucunu AI yaniti icin formatla
  def format_order_response(result)
    return format_error_response(result[:error]) unless result[:verified]

    order = result[:order]
    format_success_response(order)
  end

  # Siparis detaylarini AI context'i icin formatla
  def format_for_ai_context(order)
    parts = []
    parts << "Sipariş No: ##{order['name'] || order['id']}"
    parts << "Durum: #{translate_fulfillment_status(order['fulfillment_status'])}"
    parts << "Ödeme: #{translate_financial_status(order['financial_status'])}"
    parts << "Tutar: #{order['total_price']} #{order['currency']}"

    if order['tracking_number'].present?
      parts << "Kargo Takip No: #{order['tracking_number']}"
      parts << "Kargo Firması: #{order['tracking_company']}" if order['tracking_company'].present?
      parts << "Takip Linki: #{order['tracking_url']}" if order['tracking_url'].present?
    end

    parts.join("\n")
  end

  private

  def hook
    @hook ||= Integrations::Hook.find_by(account: @account, app_id: 'shopify')
  end

  def extract_order_number(content)
    match = content.match(ORDER_NUMBER_REGEX)
    match[1] if match
  end

  def extract_email(content)
    match = content.match(EMAIL_REGEX)
    match[0] if match
  end

  def fetch_order_by_number(order_number)
    return nil unless available?

    setup_shopify_context
    orders = shopify_client.get(
      path: 'orders.json',
      query: {
        name: order_number,
        status: 'any',
        fields: 'id,name,email,created_at,total_price,currency,fulfillment_status,financial_status,fulfillments'
      }
    ).body['orders'] || []

    return nil if orders.empty?

    order = orders.first
    tracking_info = extract_tracking_info(order['fulfillments'])
    order.merge(
      'tracking_number' => tracking_info[:tracking_number],
      'tracking_url' => tracking_info[:tracking_url],
      'tracking_company' => tracking_info[:tracking_company]
    )
  end

  def extract_tracking_info(fulfillments)
    return { tracking_number: nil, tracking_url: nil, tracking_company: nil } if fulfillments.blank?

    fulfillment = fulfillments.find { |f| f['tracking_number'].present? } || fulfillments.first

    {
      tracking_number: fulfillment&.dig('tracking_number'),
      tracking_url: fulfillment&.dig('tracking_url'),
      tracking_company: fulfillment&.dig('tracking_company')
    }
  end

  def setup_shopify_context
    return if client_id.blank? || client_secret.blank?

    ShopifyAPI::Context.setup(
      api_key: client_id,
      api_secret_key: client_secret,
      api_version: '2025-01'.freeze,
      scope: 'read_customers,read_orders,read_fulfillments',
      is_embedded: true,
      is_private: false
    )
  end

  def shopify_session
    ShopifyAPI::Auth::Session.new(shop: hook.reference_id, access_token: hook.access_token)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def client_id
    @client_id ||= GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil)
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('SHOPIFY_CLIENT_SECRET', nil)
  end

  def format_success_response(order)
    lines = []
    lines << "Siparişiniz (##{order['name'] || order['id']}) bulundu:"
    lines << "• Durum: #{translate_fulfillment_status(order['fulfillment_status'])}"
    lines << "• Ödeme: #{translate_financial_status(order['financial_status'])}"
    lines << "• Tutar: #{order['total_price']} #{order['currency']}"

    if order['tracking_number'].present?
      lines << "• Kargo Takip No: #{order['tracking_number']}"
      lines << "• Kargo Firması: #{order['tracking_company']}" if order['tracking_company'].present?
      if order['tracking_url'].present?
        lines << "• Kargo Takip: #{order['tracking_url']}"
      end
    elsif order['fulfillment_status'] == 'unfulfilled'
      lines << "• Kargo: Henüz kargoya verilmedi"
    end

    lines.join("\n")
  end

  def format_error_response(error)
    case error
    when :not_found, :email_mismatch
      'Girdiğiniz bilgilerle eşleşen sipariş bulunamadı. Lütfen sipariş numaranızı ve email adresinizi kontrol edip tekrar deneyin.'
    when :not_available
      'Şu anda sipariş sorgulama hizmeti kullanılamıyor. Lütfen daha sonra tekrar deneyin.'
    when :missing_params
      'Sipariş sorgulamak için sipariş numarası ve email adresi gereklidir.'
    else
      'Sipariş sorgulanırken bir hata oluştu. Lütfen daha sonra tekrar deneyin.'
    end
  end

  def translate_fulfillment_status(status)
    case status
    when 'fulfilled' then 'Kargoya verildi'
    when 'partial' then 'Kısmen kargoya verildi'
    when 'unfulfilled', nil then 'Hazırlanıyor'
    else status&.humanize || 'Bilinmiyor'
    end
  end

  def translate_financial_status(status)
    case status
    when 'paid' then 'Ödendi'
    when 'pending' then 'Ödeme bekleniyor'
    when 'refunded' then 'İade edildi'
    when 'partially_refunded' then 'Kısmen iade edildi'
    when 'voided' then 'İptal edildi'
    else status&.humanize || 'Bilinmiyor'
    end
  end
end

