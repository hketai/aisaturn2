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
          description: 'Mağazadaki ürünleri arar. Metin sorgusu VEYA görsel URL\'si ile arama yapabilir. GÖRSEL ARAMA: Müşteri ürün resmi gönderip "bunu istiyorum", "bu var mı" derse, gönderilen resmin URL\'sini image_url parametresine ver. METIN ARAMA: Normal ürün sorgusu için query parametresini kullan. BAĞLAM KURALI: Takip sorularında önceki kategoriden gelen bilgiyi query\'ye ekle.',
          parameters: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Metin arama sorgusu. Kategori + özellik birlikte olmalı. Örn: "siyah taşlı yüzük", "gümüş kolye". Görsel arama yapılıyorsa boş bırakılabilir.'
              },
              image_url: {
                type: 'string',
                description: 'Müşterinin gönderdiği ürün resminin URL\'si. Müşteri resim paylaşıp benzer ürün istediğinde kullan. Resim URL\'si conversation\'dan alınmalı.'
              },
              exclude_terms: {
                type: 'string',
                description: 'Hariç tutulacak terimler. "X olmasın", "Y hariç" denildiğinde kullan.'
              }
            },
            required: []
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
    # Returns: { content: String, products: Array (optional) }
    def execute_tool(tool_name:, arguments:, account:)
      case tool_name
      when 'search_products'
        execute_product_search(arguments, account)
      when 'lookup_order'
        result = execute_order_lookup(arguments, account)
        { content: result }
      else
        { content: "Bilinmeyen tool: #{tool_name}" }
      end
    rescue StandardError => e
      Rails.logger.error "[SHOPIFY TOOLS] Tool execution failed: #{e.message}"
      { content: "İşlem sırasında hata oluştu" }
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
    # Metin sorgusu VEYA görsel URL ile arama yapabilir
    # Returns: { content: String, products: Array<Shopify::Product> }
    def execute_product_search(arguments, account)
      query = arguments['query']
      image_url = arguments['image_url']
      exclude_terms = arguments['exclude_terms']

      product_service = Saturn::Shopify::ProductSearchService.new(account: account)

      # Görsel URL varsa image search yap
      if image_url.present?
        Rails.logger.info "[SHOPIFY TOOLS] Image-based search: #{image_url}"

        # Image search aktif mi kontrol et
        hook = Integrations::Hook.find_by(account: account, app_id: 'shopify')
        image_search_enabled = hook&.settings&.dig('image_search_enabled') == true

        if image_search_enabled
          # Jina CLIP ile gerçek image search
          products = product_service.search_by_image_with_rerank(
            image_url: image_url,
            text_context: query
          )

          if products.present?
            Rails.logger.info "[SHOPIFY TOOLS] Jina CLIP found #{products.size} products"
            return build_search_response(products, account, image_search: true, exclude_terms: exclude_terms)
          end
        end

        # Image search pasif veya sonuç bulamadıysa GPT-4o ile text search
        Rails.logger.info '[SHOPIFY TOOLS] Using GPT-4o text-based image analysis'
        image_analysis = Saturn::ImageAnalysisService.new(account: account)
        image_description = image_analysis.analyze_customer_image(image_url)

        if image_description.present?
          Rails.logger.info "[SHOPIFY TOOLS] GPT-4o analyzed: #{image_description}"
          query = image_description
        else
          Rails.logger.warn '[SHOPIFY TOOLS] Image analysis failed'
          return { content: 'Gönderdiğiniz resmi analiz edemedim. Lütfen aradığınız ürünü metin olarak tarif eder misiniz?' }
        end
      end

      if query.blank?
        return { content: 'Ürün aramak için bir sorgu veya görsel gerekli. Lütfen ne aradığınızı belirtin.' }
      end

      Rails.logger.info "[SHOPIFY TOOLS] Text search (with rerank): #{query}"
      products = product_service.search_with_rerank(query: query)

      build_search_response(products, account, image_search: image_url.present?, exclude_terms: exclude_terms)
    end

    # Search response oluştur
    def build_search_response(products, account, image_search: false, exclude_terms: nil)
      # Hariç tutma filtresi uygula
      if exclude_terms.present? && products.present?
        exclude_list = exclude_terms.downcase.split(/[,\s]+/).reject(&:blank?)
        original_count = products.size

        products = products.reject do |product|
          text = "#{product.title} #{product.description}".downcase
          exclude_list.any? { |term| text.include?(term) }
        end

        Rails.logger.info "[SHOPIFY TOOLS] Filtered #{original_count} → #{products.size}"
      end

      if products.blank?
        msg = image_search ? 'Gönderdiğiniz görsel ile eşleşen ürün bulunamadı.' : 'Aramanızla eşleşen ürün bulunamadı.'
        return { content: "#{msg} Farklı bir arama yapmak ister misiniz?" }
      end

      content = if image_search
                  "Gönderdiğiniz görsele benzer #{products.size} ürün buldum:\n\n" +
                    format_products_for_tool_response(products, account)
                else
                  format_products_for_tool_response(products, account)
                end

      { content: content, products: products }
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
      return nil unless hook

      # Önce custom domain'e bak, yoksa myshopify domain'i kullan
      hook.settings&.dig('custom_domain').presence || hook.reference_id
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
