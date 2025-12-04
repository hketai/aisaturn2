module Saturn
  class ProductCardsService
    MAX_PRODUCTS = 10 # Facebook carousel max limit
    
    def initialize(conversation:, products:)
      @conversation = conversation
      @products = Array(products).first(MAX_PRODUCTS)
      @inbox = conversation.inbox
      @channel = @inbox.channel
      @account = conversation.account
    end
    
    def send_product_cards
      return if @products.blank?
      return unless supported_channel?
      
      Rails.logger.info "[PRODUCT CARDS] Sending #{@products.count} product cards to #{channel_type}"
      
      result = case channel_type
               when 'Channel::FacebookPage'
                 send_facebook_carousel
               when 'Channel::Instagram'
                 send_instagram_carousel
               when 'Channel::WhatsappWeb'
                 send_whatsapp_web_products
               else
                 Rails.logger.info "[PRODUCT CARDS] Channel #{channel_type} not supported for product cards"
                 nil
               end
      
      # Carousel başarıyla gönderildiyse panele bilgi mesajı ekle
      create_panel_info_message if result.present?
      
      result
    rescue StandardError => e
      Rails.logger.error "[PRODUCT CARDS] Error sending product cards: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
    
    private
    
    def supported_channel?
      %w[Channel::FacebookPage Channel::Instagram Channel::WhatsappWeb].include?(channel_type)
    end
    
    def channel_type
      @inbox.channel_type
    end
    
    def send_facebook_carousel
      elements = build_carousel_elements
      return if elements.blank?
      
      message_params = {
        recipient: { id: contact_source_id },
        message: {
          attachment: {
            type: 'template',
            payload: {
              template_type: 'generic',
              elements: elements
            }
          }
        },
        messaging_type: 'RESPONSE'
      }
      
      deliver_facebook_message(message_params)
    end
    
    def send_instagram_carousel
      # Instagram uses the same format as Facebook Messenger
      send_facebook_carousel
    end
    
    def send_whatsapp_web_products
      # WhatsApp Web için max 3 ürün gönder (UX için optimize)
      whatsapp_products = @products.first(3)
      return if whatsapp_products.blank?
      
      Rails.logger.info "[PRODUCT CARDS] Sending #{whatsapp_products.count} products to WhatsApp Web"
      
      sent_count = 0
      whatsapp_products.each do |product|
        product_data = normalize_product(product)
        next if product_data[:title].blank?
        
        result = send_whatsapp_product_message(product_data)
        sent_count += 1 if result
      end
      
      Rails.logger.info "[PRODUCT CARDS] Successfully sent #{sent_count}/#{whatsapp_products.count} products to WhatsApp Web"
      sent_count.positive? ? { sent: sent_count } : nil
    end
    
    def send_whatsapp_product_message(product_data)
      caption = build_whatsapp_caption(product_data)
      image_url = product_data[:image_url]
      
      # Resim varsa resimle birlikte gönder, yoksa sadece metin
      if image_url.present?
        send_whatsapp_image_with_caption(image_url, caption)
      else
        send_whatsapp_text_message(caption)
      end
    end
    
    def build_whatsapp_caption(product_data)
      parts = []
      parts << product_data[:title]
      parts << format_price(product_data[:price]) if product_data[:price].present?
      parts << product_data[:url] if product_data[:url].present?
      parts.compact.join("\n")
    end
    
    def send_whatsapp_image_with_caption(image_url, caption)
      source_id = @conversation.contact_inbox.source_id
      phone_number = normalize_phone_for_whatsapp(source_id)
      
      attachments = [{
        url: image_url,
        mimetype: 'image/jpeg',
        caption: caption
      }]
      
      @channel.send_message(phone_number, nil, attachments: attachments)
    rescue StandardError => e
      Rails.logger.error "[PRODUCT CARDS] WhatsApp image send error: #{e.message}"
      nil
    end
    
    def send_whatsapp_text_message(content)
      source_id = @conversation.contact_inbox.source_id
      phone_number = normalize_phone_for_whatsapp(source_id)
      
      @channel.send_message(phone_number, content)
    rescue StandardError => e
      Rails.logger.error "[PRODUCT CARDS] WhatsApp text send error: #{e.message}"
      nil
    end
    
    def normalize_phone_for_whatsapp(phone)
      return phone if phone.blank?
      
      # LID formatını veya @ içeren formatları temizle
      phone = phone.split('@').first if phone.include?('@')
      phone = phone.gsub(/[^\d]/, '')
      phone
    end
    
    def build_carousel_elements
      @products.filter_map do |product|
        # Handle both Shopify::Product objects and hashes
        product_data = normalize_product(product)
        next if product_data[:title].blank?
        
        element = {
          title: truncate_text(product_data[:title], 80),
          subtitle: build_subtitle(product_data)
        }
        
        # Add image if available
        if product_data[:image_url].present?
          element[:image_url] = product_data[:image_url]
        end
        
        # Add default action (click on card)
        if product_data[:url].present?
          element[:default_action] = {
            type: 'web_url',
            url: product_data[:url],
            webview_height_ratio: 'tall'
          }
          
          # Add buttons
          element[:buttons] = [{
            type: 'web_url',
            url: product_data[:url],
            title: 'Ürünü Gör'
          }]
        end
        
        element
      end
    end
    
    def normalize_product(product)
      # Handle Shopify::Product ActiveRecord objects
      # Use :: prefix to reference top-level namespace
      if product.is_a?(::Shopify::Product)
        {
          title: product.title,
          description: product.description,
          price: product.min_price,
          url: build_product_url(product),
          image_url: extract_image_url(product)
        }
      else
        # Handle hash format
        product.symbolize_keys
      end
    end
    
    def build_product_url(product)
      return nil if product.handle.blank?
      
      shop_domain = shopify_shop_domain
      return nil if shop_domain.blank?
      
      "https://#{shop_domain}/products/#{product.handle}"
    end
    
    def extract_image_url(product)
      return nil if product.images.blank?
      return nil unless product.images.is_a?(Array)
      
      first_image = product.images.first
      return nil unless first_image.is_a?(Hash)
      
      first_image['src'] || first_image[:src]
    end
    
    def shopify_shop_domain
      @shopify_shop_domain ||= begin
        hook = Integrations::Hook.find_by(account_id: @account.id, app_id: 'shopify')
        hook&.reference_id
      end
    end
    
    def build_subtitle(product_data)
      parts = []
      
      # Price
      if product_data[:price].present?
        parts << format_price(product_data[:price])
      end
      
      # Description (truncated)
      if product_data[:description].present?
        desc = truncate_text(product_data[:description], 50)
        parts << desc if desc.present?
      end
      
      truncate_text(parts.join(' - '), 80)
    end
    
    def format_price(price)
      return nil unless price.present?
      
      # Format as Turkish Lira
      formatted = format('%.2f', price.to_f)
      "#{formatted} TL"
    end
    
    def truncate_text(text, max_length)
      return '' if text.blank?
      text.to_s.truncate(max_length)
    end
    
    def contact_source_id
      @conversation.contact.get_source_id(@inbox.id)
    end
    
    def deliver_facebook_message(params)
      page_id = @channel.page_id
      
      result = Facebook::Messenger::Bot.deliver(params, page_id: page_id)
      parsed = JSON.parse(result)
      
      if parsed['error'].present?
        Rails.logger.error "[PRODUCT CARDS] Facebook error: #{parsed['error']}"
        return nil
      end
      
      Rails.logger.info "[PRODUCT CARDS] Successfully sent carousel, message_id: #{parsed['message_id']}"
      parsed
    rescue JSON::ParserError => e
      Rails.logger.error "[PRODUCT CARDS] JSON parse error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "[PRODUCT CARDS] Delivery error: #{e.message}"
      nil
    end
    
    # Panelde görünen bilgi mesajı oluştur (private note)
    def create_panel_info_message
      product_list = @products.map do |product|
        product_data = normalize_product(product)
        price_text = product_data[:price].present? ? " - #{format_price(product_data[:price])}" : ''
        "• #{product_data[:title]}#{price_text}"
      end.join("\n")
      
      content = "🛍️ Ürün Kartları Gönderildi (#{@products.count} ürün)\n\n#{product_list}"
      
      # Private (internal) note olarak oluştur - sadece agent görebilir
      @conversation.messages.create!(
        account_id: @account.id,
        inbox_id: @inbox.id,
        message_type: :activity,
        content: content,
        private: true,
        content_attributes: { product_cards_sent: true }
      )
      
      Rails.logger.info "[PRODUCT CARDS] Created panel info message for conversation #{@conversation.id}"
    rescue StandardError => e
      Rails.logger.error "[PRODUCT CARDS] Failed to create panel info message: #{e.message}"
    end
  end
end

