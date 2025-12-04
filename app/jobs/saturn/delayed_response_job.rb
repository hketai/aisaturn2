# Müşteri mesajlarını bekleyip tek bir AI yanıtı oluşturan job
# Akış:
# 1. Mesaj geldiğinde bu job RESPONSE_DELAY saniye sonra çalışacak şekilde sıraya alınır
# 2. Çalışmadan önce yeni mesaj gelip gelmediği kontrol edilir
# 3. Yeni mesaj geldiyse bu job iptal edilir (yeni mesaj için yeni job zaten sırada)
# 4. AI yanıtı oluşturulduktan sonra, gönderilmeden önce tekrar kontrol yapılır
# 5. Arada yeni mesaj geldiyse yanıt gönderilmez

class Saturn::DelayedResponseJob < ApplicationJob
  queue_as :high

  # Maximum bekleme süresi - bundan sonra kesinlikle yanıt ver
  MAX_WAIT_TIME = 15

  def perform(conversation_id:, trigger_message_id:, hook_id:, first_message_at:)
    @conversation = Conversation.find_by(id: conversation_id)
    return unless @conversation

    @hook = Integrations::Hook.find_by(id: hook_id)
    return unless @hook&.enabled?

    @trigger_message_id = trigger_message_id
    @first_message_at = Time.parse(first_message_at) rescue Time.current

    Rails.logger.info "[SATURN DELAYED] Processing conversation #{conversation_id}, trigger message #{trigger_message_id}"

    # 1. Bu mesajdan sonra yeni mesaj gelmiş mi?
    unless should_respond?
      Rails.logger.info "[SATURN DELAYED] Skipping - newer message exists for conversation #{conversation_id}"
      return
    end

    # 2. Maximum bekleme süresini aştık mı? (Log için)
    if max_wait_exceeded?
      Rails.logger.info "[SATURN DELAYED] Max wait exceeded - responding now for conversation #{conversation_id}"
    end

    # 3. AI yanıtı oluştur
    trigger_message = @conversation.messages.find_by(id: @trigger_message_id)
    return unless trigger_message

    response = generate_ai_response(trigger_message)
    return if response.blank?

    # 4. Yanıt oluşturulurken yeni mesaj gelmiş mi? (Son kontrol)
    unless should_respond?
      Rails.logger.info "[SATURN DELAYED] Response cancelled - new message arrived during generation"
      return
    end

    # 5. Yanıtı gönder
    send_response(trigger_message, response)

    # Redis'teki pending işaretini temizle
    clear_pending_response

  rescue StandardError => e
    Rails.logger.error "[SATURN DELAYED] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
  end

  private

  def should_respond?
    # Conversation'daki son incoming mesaj, trigger mesajımız mı?
    # NOT: Message modelinde default_scope var, bu yüzden reorder kullanıyoruz
    latest_incoming = @conversation.messages
                                   .where(message_type: :incoming)
                                   .where(private: false)
                                   .reorder(created_at: :desc, id: :desc)
                                   .first

    return false unless latest_incoming
    
    Rails.logger.info "[SATURN DELAYED] Latest incoming: #{latest_incoming.id}, Trigger: #{@trigger_message_id}"
    
    # Eğer son mesaj trigger mesajımızsa yanıt ver
    # Veya max wait aşıldıysa, artık beklemeden yanıt ver
    latest_incoming.id == @trigger_message_id || max_wait_exceeded?
  end

  def max_wait_exceeded?
    Time.current - @first_message_at > MAX_WAIT_TIME.seconds
  end

  # Basitleştirilmiş AI yanıtı oluşturma
  # Intent detection YOK - LLM tool calling ile kendisi karar veriyor
  def generate_ai_response(message)
    @assistant = @hook.account.saturn_assistants.find_by(id: @hook.settings['assistant_id'])
    return nil unless @assistant

    # 1. Pending mesajları topla
    pending_messages = collect_pending_messages
    Rails.logger.info "[RESPONSE] Collected #{pending_messages.size} pending messages"

    # 2. Müşteri temsilcisi talebi kontrolü (basit pattern)
    if human_handoff_requested?(pending_messages)
      Rails.logger.info "[RESPONSE] → Human handoff requested"
      return handle_handoff_request
    end

    # 3. Tek LLM çağrısı - Tool calling ile (ürün arama, sipariş sorgulama vb.)
    Rails.logger.info "[RESPONSE] → Single LLM call with tool calling"
    generate_response_with_tools(pending_messages)

  rescue StandardError => e
    Rails.logger.error("[RESPONSE] Error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    'Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.'
  end

  # Müşteri temsilcisi talebi mi? (Basit pattern kontrolü)
  def human_handoff_requested?(pending_messages)
    combined = pending_messages.map(&:content).join(' ').downcase
    combined.match?(/müşteri\s*temsilci|insan|canlı\s*destek|gerçek\s*kişi/i)
  end

  # Tool calling destekli tek LLM çağrısı
  def generate_response_with_tools(pending_messages)
    @chat_service = Saturn::Llm::AssistantChatService.new(assistant: @assistant)

    user_message_content = build_combined_message_content(pending_messages)
    formatted_history = format_message_history

    @chat_service.create_ai_response(
      user_message: user_message_content,
      conversation_history: formatted_history
    )
  end

  # Handoff işlemi
  def handle_handoff_request
    return nil unless @assistant.handoff_config.present? && @assistant.handoff_config['enabled']

    handoff_processor = Saturn::HandoffProcessorService.new(
      assistant: @assistant,
      conversation: @conversation,
      intent: 'human_request'
    )

    if handoff_processor.perform
      Rails.logger.info "[RESPONSE] → Handoff triggered"
      return 'conversation_handoff'
    end

    # Handoff başarısız olduysa normal yanıt ver
    nil
  end

  # Son AI yanıtından sonra gelen TÜM incoming mesajları topla
  def collect_pending_messages
    # Son outgoing (AI) mesajını bul
    last_ai_message = @conversation.messages
                                   .where(message_type: :outgoing)
                                   .where(private: false)
                                   .reorder(created_at: :desc, id: :desc)
                                   .first

    # Son AI mesajından sonraki tüm incoming mesajları al
    query = @conversation.messages
                         .where(message_type: :incoming)
                         .where(private: false)
                         .reorder(created_at: :asc, id: :asc)

    if last_ai_message
      query = query.where('created_at > ?', last_ai_message.created_at)
    end

    query.to_a
  end


  # Birden fazla mesajı birleştir (görsel içerikler dahil)
  def build_combined_message_content(messages)
    return '' if messages.empty?

    # Tek mesaj varsa normal builder kullan
    if messages.size == 1
      message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: messages.first)
      return message_builder.generate_content
    end

    # Birden fazla mesaj varsa birleştir
    combined_parts = messages.map do |msg|
      message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: msg)
      message_builder.generate_content
    end

    # String içerikleri birleştir
    combined_parts.reject(&:blank?).join("\n\n")
  end
  
  def format_message_history
    previous_messages = []
    
    # NOT: Message modelinde default_scope var, bu yüzden reorder kullanıyoruz
    @conversation.messages
                 .where(message_type: [:outgoing, :incoming])
                 .where(private: false)
                 .reorder(created_at: :asc, id: :asc)
                 .offset(1) # İlk mesajı atla
                 .find_each do |msg|
      role = msg.message_type == 'incoming' ? 'user' : 'assistant'

      # Build message content with attachments if available
      message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: msg)
      message_content = message_builder.generate_content

      # Skip if message has no content
      next if message_content.blank? || message_content == 'Message without content'

      previous_messages << { role: role, content: message_content }
    end
    
    previous_messages
  end

  def send_response(message, response)
    return if response.blank?

    # Handoff durumunu kontrol et
    if response == 'conversation_handoff'
      message.conversation.bot_handoff!
      Rails.logger.info "[SATURN DELAYED] Handoff triggered for conversation #{@conversation.id}"
      return
    end

    assistant = @hook.account.saturn_assistants.find_by(id: @hook.settings['assistant_id'])
    return unless assistant

    # Yanıtı doğrula ve işle
    validated_response = validate_and_process_response(response, assistant)
    create_outgoing_message(message, validated_response, assistant)
    
    Rails.logger.info "[SATURN DELAYED] Response sent for conversation #{@conversation.id}"
  end

  def validate_and_process_response(response, assistant)
    # Mevcut kaynakları al
    available_faq_ids = assistant.responses.approved.pluck(:id)
    available_doc_ids = assistant.documents.available.pluck(:id)

    # Yanıtı doğrula
    validator = Saturn::Llm::ResponseValidatorService.new(
      response: response,
      available_faq_ids: available_faq_ids,
      available_document_ids: available_doc_ids
    )

    validation_result = validator.validate

    # Halüsinasyon riski yüksekse logla
    if validation_result[:hallucination_risk][:level] == :high
      Rails.logger.warn "[HALLUCINATION WARNING] High risk detected!"
      Rails.logger.warn "[HALLUCINATION WARNING] Response: #{response.truncate(200)}"
    end

    # API Usage'a kalite metriklerini ekle
    update_usage_quality_metrics(
      assistant: assistant,
      confidence: validation_result[:confidence],
      hallucination_risk: validation_result[:hallucination_risk][:level],
      no_info_response: response.include?('Bu konuda elimde yeterli bilgi bulunmuyor')
    )

    # Citation'ları parse et
    parsed = parse_citations(response, assistant)

    # Validasyon bilgilerini ekle
    parsed[:additional_attributes] ||= {}
    parsed[:additional_attributes][:confidence] = validation_result[:confidence]
    parsed[:additional_attributes][:hallucination_risk] = validation_result[:hallucination_risk][:level]

    parsed
  end

  def update_usage_quality_metrics(assistant:, confidence:, hallucination_risk:, no_info_response:)
    return unless defined?(Saturn::ApiUsage)

    last_usage = Saturn::ApiUsage.where(
      saturn_assistant_id: assistant.id,
      api_type: 'chat'
    ).order(created_at: :desc).first

    return unless last_usage && last_usage.created_at > 30.seconds.ago

    last_usage.update(
      confidence: confidence.to_s,
      hallucination_risk: hallucination_risk.to_s,
      no_info_response: no_info_response
    )
  rescue StandardError => e
    Rails.logger.error "[API TRACKING] Failed to update quality metrics: #{e.message}"
  end

  def parse_citations(response, assistant)
    faq_pattern = /\[SSS_(\d+)\]/i
    doc_pattern = /\[DOKÜMAN_(\d+)\]/i
    confidence_pattern = /\[GÜVEN:\s*(YÜKSEK|ORTA|DÜŞÜK)\]/i

    # Citation özelliği kapalıysa sadece temizleme yap
    unless assistant&.feature_citation == true
      cleaned = clean_response_tags(response, confidence_pattern)
      return { content: cleaned }
    end

    faq_citations = response.scan(faq_pattern).flatten.map(&:to_i).uniq
    doc_citations = response.scan(doc_pattern).flatten.map(&:to_i).uniq

    citations = {}

    if doc_citations.any?
      documents = assistant.documents.where(id: doc_citations).index_by(&:id)
      doc_citations.each do |doc_id|
        citations["DOKÜMAN_#{doc_id}"] = documents[doc_id]&.name if documents[doc_id]
      end
    end

    if faq_citations.any?
      faqs = assistant.responses.approved.limit(10).to_a
      faq_citations.each do |faq_num|
        faq = faqs[faq_num - 1]
        citations["SSS_#{faq_num}"] = faq&.question&.truncate(50) if faq
      end
    end

    cleaned_response = clean_response_tags(response, confidence_pattern)

    result = { content: cleaned_response }
    result[:additional_attributes] = { citations: citations } if citations.any?

    result
  end

  def create_outgoing_message(message, content_params, assistant)
    return if content_params.blank?

    conversation = message.conversation
    message_attrs = {
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: assistant
    }

    message_attrs[:additional_attributes] = content_params[:additional_attributes] if content_params[:additional_attributes].present?

    conversation.messages.create!(
      content_params.except(:additional_attributes).merge(message_attrs)
    )
  end

  def clear_pending_response
    redis_key = "saturn:pending_response:#{@conversation.id}"
    Redis::Alfred.delete(redis_key)
  rescue StandardError => e
    Rails.logger.warn "[SATURN DELAYED] Redis clear failed: #{e.message}"
  end

  def clean_response_tags(response, confidence_pattern = nil)
    confidence_pattern ||= /\[GÜVEN:\s*(YÜKSEK|ORTA|DÜŞÜK)\]/i
    
    response
      .gsub(confidence_pattern, '')
      .gsub(/\[SSS_\d+\]/i, '')
      .gsub(/\[SSS\]/i, '')
      .gsub(/\[DOKÜMAN_\d+\]/i, '')
      .gsub(/\[ÜRÜN_\d+\]/i, '')
      .gsub(/\[GÜVEN\s*:\s*(YÜKSEK|ORTA|DÜŞÜK)\s*\]/i, '')
      .gsub(/\*\*([^*]+)\*\*/i, '\1')
      .gsub(/\*([^*]+)\*/i, '\1')
      .gsub(/\[([^\]]+)\]\([^)]+\)/i, '\1')
      .gsub(/Başka bir konuda yardımcı olabilir miyim\??/i, '')
      .gsub(/\n\s*\n\s*\n/, "\n\n")
      .strip
  end
end
