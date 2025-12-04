require 'openai'

class Saturn::Llm::AssistantChatService < Saturn::Llm::BaseOpenAiService
  SECTOR_NAMES = {
    'ecommerce' => 'E-Ticaret',
    'fashion' => 'Moda & Giyim',
    'jewelry' => 'Takı & Aksesuar',
    'electronics' => 'Elektronik',
    'food' => 'Yiyecek & İçecek',
    'health' => 'Sağlık & Güzellik',
    'travel' => 'Seyahat & Turizm',
    'real_estate' => 'Emlak',
    'automotive' => 'Otomotiv',
    'education' => 'Eğitim',
    'finance' => 'Finans & Bankacılık',
    'technology' => 'Teknoloji & Yazılım',
    'services' => 'Hizmet Sektörü',
    'other' => 'Diğer'
  }.freeze

  MAX_HISTORY_MESSAGES = 10
  MAX_RELEVANT_FAQS = 5
  MAX_RELEVANT_CHUNKS = 5
  MAX_RELEVANT_PRODUCTS = 5
  CONTEXT_MESSAGES_FOR_SEARCH = 10 # Semantic search için kaç mesaj bağlam kullanılacak

  attr_reader :found_products, :intent_result
  
  def initialize(assistant: nil, user_message: nil, conversation_history: [], intent_result: nil)
    super()
    @assistant = assistant
    @user_message = user_message
    @conversation_history = conversation_history || []
    @found_products = [] # Store found products for potential carousel display
    @intent_result = intent_result # Multi-intent analiz sonucu
    
    # API Usage Tracking için set et
    self.tracking_assistant = assistant
    self.tracking_account = assistant&.account
  end

  def create_ai_response(user_message: nil, conversation_history: [], message_role: 'user')
    # User message'ı güncelle (eğer parametre olarak geldiyse)
    @user_message = user_message if user_message.present?
    @conversation_history = conversation_history if conversation_history.present?
    
    # Bağlam içeren arama sorgusu oluştur
    @context_aware_query = build_context_aware_query
    
    # System prompt'u context_aware_query ile oluştur (semantic search için)
    initialize_message_history
    
    append_conversation_history(@conversation_history)
    append_user_message(@user_message, message_role) if @user_message.present?

    # Shopify tool'ları ekle (aktifse)
    tools = shopify_order_tools_enabled? ? Saturn::Shopify::ToolsService.order_lookup_tools : nil

    # İlk API çağrısı
    response = execute_chat_api_with_tools(messages: @messages, tools: tools, temperature: get_temperature_setting)

    response
  end

  # Tool calling destekli API çağrısı
  def execute_chat_api_with_tools(messages:, tools:, temperature:)
    start_time = Time.current
    api_params = build_chat_params_with_tools(messages, tools, temperature)
    api_response = call_openai_api(api_params)
    response_time = Time.current - start_time

    # Tool call var mı kontrol et
    message = api_response.dig('choices', 0, 'message')
    tool_calls = message['tool_calls']

    if tool_calls.present?
      # Tool call'ları işle
      handle_tool_calls(messages, message, tool_calls, tools, temperature)
    else
      # Normal yanıt
      track_chat_usage(api_response, response_time)
      message['content']
    end
  rescue StandardError => e
    track_chat_error(e)
    handle_api_error(e)
    raise
  end

  def handle_tool_calls(messages, assistant_message, tool_calls, tools, temperature)
    # Assistant mesajını ekle
    messages << assistant_message

    # Her tool call için sonuçları al
    tool_calls.each do |tool_call|
      tool_name = tool_call.dig('function', 'name')
      arguments = JSON.parse(tool_call.dig('function', 'arguments') || '{}')

      Rails.logger.info "[SHOPIFY TOOL] Calling #{tool_name} with #{arguments.inspect}"

      # Tool'u çalıştır
      tool_result = Saturn::Shopify::ToolsService.execute_tool(
        tool_name: tool_name,
        arguments: arguments,
        account: @assistant.account
      )

      # Tool sonucunu mesajlara ekle
      messages << {
        role: 'tool',
        tool_call_id: tool_call['id'],
        content: tool_result.to_s
      }
    end

    # İkinci API çağrısı (tool sonuçlarıyla)
    second_response = call_openai_api(build_chat_params_with_tools(messages, tools, temperature))
    second_message = second_response.dig('choices', 0, 'message')

    # Yine tool call varsa recursive olarak işle (max 3 seviye)
    if second_message['tool_calls'].present? && @tool_call_depth.to_i < 3
      @tool_call_depth = @tool_call_depth.to_i + 1
      handle_tool_calls(messages, second_message, second_message['tool_calls'], tools, temperature)
    else
      second_message['content']
    end
  end

  def build_chat_params_with_tools(messages, tools, temperature)
    params = {
      model: model,
      messages: messages
    }
    params[:tools] = tools if tools.present?
    params[:temperature] = temperature if temperature.present?
    params
  end

  def call_openai_api(params)
    client.chat(parameters: params)
  end

  private

  def initialize_message_history
    @messages = [build_system_message]
  end

  def build_system_message
    {
      role: 'system',
      content: construct_prompt_template
    }
  end

  def construct_prompt_template
    template_parts = []
    template_parts << build_general_instructions
    template_parts << build_assistant_introduction
    template_parts << build_sector_section
    template_parts << build_description_section
    template_parts << build_faqs_section if feature_faq_enabled?
    template_parts << build_documents_section if feature_citation_enabled?
    template_parts << build_shopify_products_section if shopify_products_enabled?
    template_parts << build_shopify_order_instructions if shopify_order_tools_enabled?
    template_parts.compact.join("\n\n")
  end

  def build_general_instructions
    <<~INSTRUCTIONS
      # Genel Talimatlar

      Sen yardımcı, samimi ve bilgili bir AI asistanısın. Temel rolün, kullanıcılara doğru bilgi sağlayarak, sorularını yanıtlayarak ve görevlerini tamamlamalarına yardımcı olmaktır.

      ## Temel Prensipler

      - **Konuşma Tarzı**: Doğal, nazik ve konuşma dilinde, anlaşılması kolay bir dil kullan. Cümleleri kısa tut ve basit kelimeler kullan.
      - **Dil Algılama**: Kullanıcının girdiğindeki dili her zaman algıla ve aynı dilde yanıt ver. Başka bir dil kullanma.
      - **Kısa ve Öz Ol**: Yanıtların çoğu kısa ve ilgili olmalı—genellikle bir veya iki cümle, daha detaylı bir açıklama gerekmedikçe.
      - **Netleştirme İste**: Belirsizlik olduğunda, varsayım yapmak yerine kısa netleştirme soruları sor.
      - **Doğal Akış**: Doğal bir şekilde etkileşimde bulun ve uygun olduğunda ilgili takip soruları sor. Konuşmanın akışını sürdür.
      - **Profesyonel Ton**: Konuşma boyunca profesyonel ama samimi bir ton koru.

      ## 🚫 HALÜSİNASYON KURALLARI (ÇOK ÖNEMLİ!)

      Bu kurallar kesinlikle ihlal edilmemelidir:

      1. **SADECE VERİLEN BİLGİLERİ KULLAN**: Yanıtlarını YALNIZCA aşağıda sağlanan SSS ve döküman bilgilerine dayandır. Kendi eğitim verilerini veya genel bilgilerini ASLA kullanma.

      2. **BİLMİYORSAN SÖYLE**: Eğer soru, sağlanan SSS veya dökümanlarda yanıtlanamıyorsa, şu formatta yanıt ver:
         "Bu konuda elimde yeterli bilgi bulunmuyor. Size daha doğru bilgi verebilmem için müşteri hizmetlerimize ulaşmanızı öneririm."

      3. **ASLA UYDURMA**:
         - Fiyat, tarih, süre, miktar gibi sayısal bilgileri ASLA tahmin etme
         - Ürün özellikleri, politikalar veya prosedürler hakkında bilgi UYDURMA
         - "Genellikle", "muhtemelen", "sanırım" gibi belirsiz ifadeler kullanma

      4. **KAYNAK GÖSTER**: Her yanıtında bilgiyi nereden aldığını belirt:
         - SSS'ten aldıysan: [SSS] etiketi kullan
         - Dökümandan aldıysan: [DOKÜMAN_X] etiketi kullan
         - Kaynak gösteremiyorsan, bilgiyi verme!

      5. **GÜVENİLİRLİK**: Yanıtının sonuna güven seviyeni ekle:
         - [GÜVEN: YÜKSEK] - Bilgi doğrudan SSS/dökümanda var
         - [GÜVEN: ORTA] - Bilgi dolaylı olarak çıkarılabilir
         - [GÜVEN: DÜŞÜK] - Bilgi tam olarak yok, müşteri hizmetlerine yönlendir

      ## Yanıt Kuralları

      - Konuşmayı açıkça bitirmeye çalışma (örneğin, "Görüşürüz!" veya "Başka bir şeye ihtiyacın olursa haber ver" gibi ifadelerden kaçın).
      - Başka bir şeye ihtiyaçları olup olmadığını sorma (örneğin, "Başka nasıl yardımcı olabilirim?" gibi şeyler söyleme).
      - Mevcut bilgilere dayanarak yararlı bir yanıt sağlayamıyorsan, "Bu konuda elimde yeterli bilgi bulunmuyor" de ve müşteri hizmetlerine yönlendir.
    INSTRUCTIONS
  end

  def build_assistant_introduction
    "## Kimliğin\n\nSen #{@assistant.name}, yardımcı bir AI asistanısın."
  end

  def build_sector_section
    return nil unless @assistant.sector.present?

    sector_name = SECTOR_NAMES[@assistant.sector] || @assistant.sector
    "## Sektör\n\nBu asistan #{sector_name} sektöründe hizmet vermektedir. Yanıtlarını bu sektöre uygun terminoloji ve yaklaşımla ver."
  end

  def build_description_section
    return nil unless @assistant.description.present?

    "## Açıklama\n\n#{@assistant.description}"
  end

  def build_faqs_section
    # Kullanıcı mesajı yoksa veya SSS yoksa, boş dön
    return nil if @user_message.blank?

    # Semantic search ile en alakalı SSS'leri bul
    @relevant_faqs = find_relevant_faqs
    return nil if @relevant_faqs.empty?

    faqs_text = "## Sık Sorulan Sorular (FAQ)\n\n"
    faqs_text += "SADECE aşağıdaki SSS bilgilerini kullan. Bu bilgilerin dışına ÇIKMA:\n\n"

    @relevant_faqs.each_with_index do |faq, index|
      faqs_text += "[SSS_#{index + 1}] **Soru**: #{faq.question}\n"
      faqs_text += "   **Cevap**: #{faq.answer}\n\n"
    end

    faqs_text += "\nBu SSS'lerden bilgi kullandığında [SSS_X] formatında kaynak göster.\n"
    faqs_text
  end

  def find_relevant_faqs
    semantic_service = Saturn::Llm::SemanticFaqService.new
    semantic_service.find_relevant_faqs(
      assistant: @assistant,
      query: @context_aware_query || @user_message,
      limit: MAX_RELEVANT_FAQS
    )
  rescue StandardError => e
    Rails.logger.error "[CHAT SERVICE] Semantic FAQ search failed: #{e.message}"
    # Fallback: Son 5 SSS'i getir
    @assistant.responses.approved.limit(MAX_RELEVANT_FAQS)
  end

  def build_documents_section
    # Kullanıcı mesajı yoksa fallback kullan
    return build_documents_section_fallback if @user_message.blank?

    # Semantic search ile en alakalı chunk'ları bul
    chunks = find_relevant_document_chunks
    
    # Chunk bulunamazsa fallback kullan
    return build_documents_section_fallback if chunks.empty?

    docs_text = "## Referans Dökümanlar\n\n"
    docs_text += "Aşağıdaki döküman bölümleri, kullanıcının sorusuyla en alakalı bilgileri içermektedir. Bu bilgileri referans al:\n\n"

    # Chunk'ları döküman bazında grupla
    chunks_by_document = chunks.group_by(&:document)
    
    chunks_by_document.each do |document, doc_chunks|
      doc_id = document.id
      docs_text += "### [DOKÜMAN_#{doc_id}] #{document.name}\n\n"
      
      doc_chunks.each_with_index do |chunk, index|
        docs_text += "**Bölüm #{index + 1}:**\n#{chunk.content}\n\n"
      end
    end

    docs_text += "\nÖNEMLİ: Yanıtlarında hangi dökümandan bilgi kullandıysan, yanıtının sonunda [DOKÜMAN_X] formatında kaynak göster. Örnek: 'Bu bilgi [DOKÜMAN_1] dökümanından alınmıştır.'\n"

    docs_text
  end

  def find_relevant_document_chunks
    semantic_service = Saturn::Llm::SemanticDocumentService.new
    semantic_service.find_relevant_chunks(
      assistant: @assistant,
      query: @context_aware_query || @user_message,
      limit: MAX_RELEVANT_CHUNKS
    )
  rescue StandardError => e
    Rails.logger.error "[CHAT SERVICE] Semantic document search failed: #{e.message}"
    []
  end

  def build_documents_section_fallback
    # Fallback: İlk 5 dökümanın ilk 1000 karakterini al
    documents = @assistant.documents.available.limit(5)
    return nil if documents.empty?

    docs_text = "## Referans Dökümanlar\n\n"
    docs_text += "Aşağıdaki dökümanlardaki bilgileri kullanarak kullanıcılara yardımcı ol:\n\n"

    documents.each do |doc|
      doc_id = doc.id
      docs_text += "### [DOKÜMAN_#{doc_id}] #{doc.name}\n"
      next unless doc.content.present?

      content_preview = doc.content.first(1000)
      docs_text += "#{content_preview}\n\n"
    end

    docs_text += "\nÖNEMLİ: Yanıtlarında hangi dökümandan bilgi kullandıysan, yanıtının sonunda [DOKÜMAN_X] formatında kaynak göster.\n"

    docs_text
  end

  def append_conversation_history(history)
    return unless history.present?

    # Filter out any system messages from history to avoid duplicates
    filtered_history = history.reject { |msg| msg[:role] == 'system' || msg['role'] == 'system' }
    
    # Son MAX_HISTORY_MESSAGES mesajı al (token optimizasyonu)
    recent_history = filtered_history.last(MAX_HISTORY_MESSAGES)
    
    @messages += recent_history
  end

  def append_user_message(message, role)
    # Message can be a string or an array (for multi-part messages with images)
    @messages << { role: role, content: message }
  end

  # Konuşma bağlamını içeren arama sorgusu oluştur
  # Bu, "Fiyatı ne kadar?" gibi bağlam gerektiren soruları
  # "iPhone 15 Pro Max fiyatı ne kadar?" gibi zenginleştirir
  def build_context_aware_query
    return @user_message if @user_message.blank?
    return @user_message if @conversation_history.blank? || @conversation_history.empty?

    # Son CONTEXT_MESSAGES_FOR_SEARCH mesajı al (user + assistant)
    recent_messages = extract_recent_context

    # Eğer önceki mesaj yoksa sadece user_message döndür
    return @user_message if recent_messages.empty?

    # Bağlamı birleştir
    context_text = recent_messages.map do |msg|
      role = msg[:role] || msg['role']
      content = extract_message_content(msg[:content] || msg['content'])
      "#{role == 'user' ? 'Kullanıcı' : 'Asistan'}: #{content}"
    end.join("\n")

    # Bağlam + mevcut soru
    combined_query = "#{context_text}\nKullanıcı: #{@user_message}"

    Rails.logger.info "[CONTEXT QUERY] Original: '#{@user_message}'"
    Rails.logger.info "[CONTEXT QUERY] With context: '#{combined_query.truncate(200)}'"

    combined_query
  end

  def extract_recent_context
    # System mesajlarını filtrele
    filtered = @conversation_history.reject do |msg|
      role = msg[:role] || msg['role']
      role == 'system'
    end

    # Son N mesajı al (mevcut mesaj hariç)
    # Son mesaj zaten @user_message olacağı için son N-1 mesajı alıyoruz
    filtered.last(CONTEXT_MESSAGES_FOR_SEARCH)
  end

  def extract_message_content(content)
    # Content string veya array olabilir (multimodal mesajlar için)
    return content if content.is_a?(String)
    return '' if content.blank?

    # Array ise text kısımlarını birleştir
    if content.is_a?(Array)
      text_parts = content.select { |part| part[:type] == 'text' || part['type'] == 'text' }
      return text_parts.map { |part| part[:text] || part['text'] }.join(' ')
    end

    content.to_s
  end

  def get_temperature_setting
    @assistant&.temperature
  end

  def feature_faq_enabled?
    @assistant&.feature_faq == true
  end

  def feature_citation_enabled?
    @assistant&.feature_citation == true
  end

  # ===== SHOPIFY ENTEGRASYONU =====

  def shopify_enabled?
    return false unless @assistant.present?

    @assistant.shopify_enabled?
  end

  def shopify_products_enabled?
    return false unless shopify_enabled?

    # Intent sonucu varsa, ürün araması gerekip gerekmediğini kontrol et
    if @intent_result.present?
      return false unless should_search_products_by_intent?
    end

    # Shopify ürün sayısını kontrol et
    product_service = Saturn::Shopify::ProductSearchService.new(account: @assistant.account)
    product_service.available? && product_service.product_count.positive?
  end

  # Intent sonucuna göre ürün araması yapılmalı mı?
  def should_search_products_by_intent?
    return true if @intent_result.blank?

    intents = @intent_result[:intents] || []

    # Ürün sorgusu intent'i varsa kesinlikle ara
    return true if intents.include?(:product_query)

    # Ürün keyword'leri varsa ara
    return true if @intent_result[:product_keywords].present?

    # Sadece selamlama, teşekkür, veda, onay intent'leri varsa arama yapma
    non_product_intents = %i[greeting farewell thanks confirmation human_request]
    return false if intents.all? { |i| non_product_intents.include?(i) }

    # Diğer durumlarda da arama yapmayabiliriz
    # general_question, complaint gibi intent'ler için SSS/doküman araması yeterli
    false
  end

  def shopify_order_tools_enabled?
    return false unless shopify_enabled?

    order_service = Saturn::Shopify::OrderLookupService.new(account: @assistant.account)
    order_service.available?
  end

  def build_shopify_products_section
    # Intent kontrolü - ürün araması gerekli mi?
    return nil unless should_search_products_by_intent?
    return nil if @user_message.blank? && @intent_result.blank?

    # Ürünleri ara
    products = find_relevant_shopify_products
    return nil if products.blank?

    product_service = Saturn::Shopify::ProductSearchService.new(account: @assistant.account)
    formatted_products = product_service.format_for_prompt(products)
    return nil if formatted_products.blank?

    # Intent bilgisini logla
    if @intent_result.present?
      Rails.logger.info "[CHAT SERVICE] Product search triggered by intents: #{@intent_result[:intents].inspect}"
      Rails.logger.info "[CHAT SERVICE] Product keywords: #{@intent_result[:product_keywords].inspect}"
    end

    <<~SHOPIFY
      ## Shopify Ürünleri

      Kullanıcının sorusuyla alakalı ürün bilgileri aşağıdadır. Bu bilgileri kullanarak ürün önerileri yapabilirsin:

      #{formatted_products}

      ÖNEMLİ: Ürün bilgilerini kullandığında [ÜRÜN_X] formatında referans ver.
    SHOPIFY
  end

  def find_relevant_shopify_products
    product_service = Saturn::Shopify::ProductSearchService.new(account: @assistant.account)

    # Intent sonucunda product_keywords varsa onları kullan
    # Yoksa kullanıcı mesajını kullan
    search_query = if @intent_result.present? && @intent_result[:product_keywords].present?
                     # Intent'ten çıkarılan keyword'leri kullan
                     @intent_result[:product_keywords].join(' ')
                   elsif @intent_result.present? && @intent_result[:combined_message].present?
                     # Birleştirilmiş mesajı kullan
                     @intent_result[:combined_message]
                   else
                     # Sadece mevcut kullanıcı mesajını kullan
                     @user_message
                   end

    Rails.logger.info "[CHAT SERVICE] Searching products with query: #{search_query.to_s.truncate(100)}"

    products = product_service.search(
      query: search_query,
      limit: MAX_RELEVANT_PRODUCTS
    )

    # Store products for potential carousel display
    @found_products = products
    products
  rescue StandardError => e
    Rails.logger.error "[CHAT SERVICE] Shopify product search failed: #{e.message}"
    @found_products = []
    []
  end

  def build_shopify_order_instructions
    <<~ORDER_INSTRUCTIONS
      ## Sipariş Sorgulama Yetenekleri

      Bu asistan Shopify siparişlerini sorgulama yeteneğine sahiptir.

      ⚠️ **GÜVENLİK KURALI**: Sipariş sorgulamak için HEM email adresi HEM DE sipariş numarası GEREKLİDİR.

      ### Sipariş Sorgulama Akışı:

      1. Müşteri sipariş durumunu sorduğunda:
         - Email adresini ve sipariş numarasını iste

      2. Her iki bilgi de alındıktan sonra `lookup_order` tool'unu kullan.

      3. Tool'dan gelen sipariş bilgisini OLDUĞU GİBİ paylaş:
         - Markdown formatı KULLANMA (*, **, [], () gibi)
         - Ekstra metin EKLEME ("Başka bir konuda yardımcı olabilir miyim?" gibi)
         - Sadece tool'un döndürdüğü bilgiyi ver
         - [GÜVEN: ...] etiketi EKLEME

      4. Sipariş bulunamazsa:
         "Girdiğiniz bilgilerle eşleşen bir sipariş bulunamadı."

      ÖNEMLİ: Sipariş bilgisi verdikten sonra konuşmayı uzatma, ekstra soru sorma.
    ORDER_INSTRUCTIONS
  end
end
