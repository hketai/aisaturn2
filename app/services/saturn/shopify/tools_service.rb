# OpenAI Function Calling için Shopify tool tanımları
class Saturn::Shopify::ToolsService
  class << self
    # Tüm Shopify tool'larını döndür
    def all_tools(account:)
      tools = []
      
      # Ürün arama tool'u (Shopify entegrasyonu varsa)
      if product_search_available?(account)
        tools << product_search_tool
      end
      
      # Sipariş sorgulama tool'u (Shopify entegrasyonu varsa)
      if order_lookup_available?(account)
        tools << order_lookup_tool
      end
      
      tools
    end
    
    # Ürün arama tool tanımı
    def product_search_tool
      {
        type: 'function',
        function: {
          name: 'search_products',
          description: 'Mağazadaki ürünleri arar. Müşteri ürün sorduğunda, ürün önerisi istediğinde veya "X var mı?", "Y göster", "hangi ürünler var" gibi sorular sorduğunda bu tool\'u kullan. Önceki konuşmada bir ürün kategorisinden bahsedildiyse (örn: kolye) ve müşteri "kırmızısı var mı?" derse, o kategoride kırmızı ürün ara.',
          parameters: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Arama sorgusu. Ürün adı, kategori, renk, özellik vb. içerebilir. Örn: "kırmızı kolye", "altın bileklik", "taşlı yüzük"'
              }
            },
            required: ['query']
          }
        }
      }
    end
    
    # Sipariş sorgulama tool tanımı
    def order_lookup_tool
      {
        type: 'function',
        function: {
          name: 'lookup_order',
          description: 'Müşterinin sipariş durumunu sorgular. GÜVENLİK: Hem email adresi hem de sipariş numarası birlikte gereklidir. Müşteri "siparişim nerede", "kargom ne durumda" gibi sorular sorduğunda, önce email ve sipariş numarasını iste, sonra bu tool\'u kullan.',
          parameters: {
            type: 'object',
            properties: {
              email: {
                type: 'string',
                description: 'Müşterinin sipariş verirken kullandığı email adresi (örn: ornek@email.com)'
              },
              order_number: {
                type: 'string',
                description: 'Sipariş numarası (örn: #1001 veya 1001). Müşteriye gönderilen sipariş onay emailinde bulunur.'
              }
            },
            required: %w[email order_number]
          }
        }
      }
    end
    
    # Legacy: Sadece sipariş tool'ları
    def order_lookup_tools
      [order_lookup_tool]
    end

    # Tool çağrısını işle
    def execute_tool(tool_name:, arguments:, account:)
      case tool_name
      when 'search_products'
        execute_product_search(arguments, account)
      when 'lookup_order'
        execute_order_lookup(arguments, account)
      else
        { error: "Bilinmeyen tool: #{tool_name}" }
      end
    rescue StandardError => e
      Rails.logger.error "[SHOPIFY TOOLS] Tool execution failed: #{e.message}"
      { error: "İşlem sırasında hata oluştu" }
    end
    
    # Ürün araması yapılabilir mi?
    def product_search_available?(account)
      return false unless account.present?
      
      hook = Integrations::Hook.find_by(account: account, app_id: 'shopify')
      return false unless hook&.enabled?
      
      Shopify::Product.for_account(account.id).exists?
    end
    
    # Sipariş sorgulaması yapılabilir mi?
    def order_lookup_available?(account)
      return false unless account.present?
      
      hook = Integrations::Hook.find_by(account: account, app_id: 'shopify')
      hook&.enabled? && hook&.access_token.present?
    end

    private
    
    # Ürün araması yap
    def execute_product_search(arguments, account)
      query = arguments['query']
      
      if query.blank?
        return "Ürün aramak için bir sorgu gerekli. Lütfen ne aradığınızı belirtin."
      end
      
      Rails.logger.info "[SHOPIFY TOOLS] Product search: #{query}"
      
      product_service = Saturn::Shopify::ProductSearchService.new(account: account)
      products = product_service.search(query: query, limit: 5)
      
      if products.blank?
        return "Aramanızla eşleşen ürün bulunamadı. Farklı bir arama yapmak ister misiniz?"
      end
      
      # Ürünleri formatla
      format_products_for_tool_response(products, account)
    end
    
    # Ürünleri tool response formatında döndür
    def format_products_for_tool_response(products, account)
      shop_domain = get_shop_domain(account)
      
      result = "#{products.size} ürün bulundu:\n\n"
      
      products.each_with_index do |product, index|
        result += "[ÜRÜN_#{index + 1}]\n"
        result += "Ad: #{product.title}\n"
        
        # Fiyat
        if product.min_price.present?
          if product.min_price == product.max_price || product.max_price.blank?
            result += "Fiyat: #{product.min_price} TL\n"
          else
            result += "Fiyat: #{product.min_price} - #{product.max_price} TL\n"
          end
        end
        
        # Stok
        if product.total_inventory.present?
          stock = product.total_inventory.positive? ? "Stokta (#{product.total_inventory} adet)" : "Stokta Yok"
          result += "Stok: #{stock}\n"
        end
        
        # Link
        if product.handle.present? && shop_domain.present?
          result += "Link: https://#{shop_domain}/products/#{product.handle}\n"
        end
        
        # Açıklama (kısa)
        if product.description.present?
          desc = product.description.gsub(/<[^>]*>/, '').strip.truncate(150)
          result += "Açıklama: #{desc}\n"
        end
        
        result += "\n"
      end
      
      result
    end
    
    def get_shop_domain(account)
      hook = Integrations::Hook.find_by(account: account, app_id: 'shopify')
      hook&.reference_id
    end

    def execute_order_lookup(arguments, account)
      email = arguments['email']
      order_number = arguments['order_number']

      # Her iki parametre de gerekli
      if email.blank? || order_number.blank?
        return "Sipariş durumunu sorgulamak için hem email adresinizi hem de sipariş numaranızı vermeniz gerekmektedir. Lütfen bu bilgileri paylaşır mısınız?"
      end

      order_service = Saturn::Shopify::OrderLookupService.new(account: account)
      result = order_service.lookup_order(email: email, order_number: order_number)

      if result[:error].present?
        result[:error]
      elsif result[:success] && result[:order].present?
        format_order_for_response(result[:order])
      else
        "Sipariş bilgisi alınamadı. Lütfen bilgilerinizi kontrol ediniz."
      end
    end

    def format_order_for_response(order)
      lines = []
      
      # İptal edilmiş mi?
      if order[:cancelled]
        lines << "#{order[:order_number]} no'lu siparişiniz iptal edilmiştir."
        lines << "İptal sebebi: #{order[:cancel_reason]}" if order[:cancel_reason].present?
        return lines.join("\n")
      end

      # Kargo durumuna göre kısa mesaj
      case order[:status]
      when 'Teslim Edildi'
        lines << "#{order[:order_number]} no'lu siparişiniz teslim edilmiştir."
      when 'Hazırlanıyor'
        lines << "#{order[:order_number]} no'lu siparişiniz hazırlanıyor, henüz kargoya verilmedi."
      when 'Gönderimde', 'İşleniyor', 'Kısmen Gönderildi'
        lines << "#{order[:order_number]} no'lu siparişiniz kargoya verilmiştir."
      else
        lines << "#{order[:order_number]} no'lu siparişiniz işleme alınmıştır."
        lines << "Durum: #{order[:status]}"
      end

      # Kargo takip bilgisi varsa ekle
      if order[:tracking].present? && order[:tracking].any?
        lines << ""
        order[:tracking].each do |t|
          lines << "Kargo Şirketi: #{t[:company] || 'Kargo Firması'}"
          lines << "Takip Numarası: #{t[:tracking_number]}"
          lines << "Takip Linki: #{t[:tracking_url]}" if t[:tracking_url].present?
        end
      end

      lines.join("\n")
    end
  end
end
