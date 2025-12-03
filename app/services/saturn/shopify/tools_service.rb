# OpenAI Function Calling için Shopify tool tanımları
# GÜVENLİK: Email VE sipariş numarası birlikte gerekli
class Saturn::Shopify::ToolsService
  class << self
    # Sipariş sorgulama için tool tanımı (güvenli - her iki bilgi gerekli)
    def order_lookup_tools
      [
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
      ]
    end

    # Tool çağrısını işle
    def execute_tool(tool_name:, arguments:, account:)
      case tool_name
      when 'lookup_order'
        execute_order_lookup(arguments, account)
      else
        { error: "Bilinmeyen tool: #{tool_name}" }
      end
    rescue StandardError => e
      Rails.logger.error "[SHOPIFY TOOLS] Tool execution failed: #{e.message}"
      { error: "İşlem sırasında hata oluştu" }
    end

    private

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
