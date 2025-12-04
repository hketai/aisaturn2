class Integrations::Saturn::ProcessorService < Integrations::BotProcessorService
  pattr_initialize [:event_name!, :hook!, :event_data!]

  # Delayed response için bekleme süresi (saniye)
  RESPONSE_DELAY = 3

  # Override: Direkt yanıt yerine delayed job sıraya al
  def perform
    message = event_data[:message]
    return unless should_run_processor?(message)

    # Delayed job'ı sıraya al
    queue_delayed_response(message)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: hook&.account).capture_exception
  end

  private

  def should_run_processor?(message)
    return if message.private?
    return unless processable_message?(message)
    return unless conversation.pending? || conversation.open?

    true
  end

  def processable_message?(message)
    message.reportable? && !message.outgoing?
  end

  def queue_delayed_response(message)
    # Mevcut bekleyen job'ları Redis'te işaretle (opsiyonel optimizasyon)
    mark_pending_response(message.conversation_id)

    # Delayed job'ı RESPONSE_DELAY saniye sonra çalışacak şekilde sıraya al
    Saturn::DelayedResponseJob.set(wait: RESPONSE_DELAY.seconds).perform_later(
      conversation_id: message.conversation_id,
      trigger_message_id: message.id,
      hook_id: hook.id,
      first_message_at: Time.current.iso8601
    )

    Rails.logger.info "[SATURN] Delayed response queued for conversation #{message.conversation_id}, message #{message.id}"
  end

  def mark_pending_response(conversation_id)
    # Redis'te bu conversation için pending response olduğunu işaretle
    redis_key = "saturn:pending_response:#{conversation_id}"
    Redis::Alfred.setex(redis_key, 30, Time.current.to_i)
  rescue StandardError => e
    Rails.logger.warn "[SATURN] Redis mark failed: #{e.message}"
  end

  # Legacy: Direkt yanıt için (delayed job tarafından çağrılır)
  def get_response(_session_id, _message_content)
    message = event_data[:message]
    call_saturn(message)
  end

  def process_response(message, response)
    if response == 'conversation_handoff'
      message.conversation.bot_handoff!
    else
      # Yanıtı doğrula ve halüsinasyon riskini değerlendir
      validated_response = validate_and_process_response(response, message)
      create_conversation(message, validated_response)
    end
  end

  def validate_and_process_response(response, _message)
    assistant = hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
    return { content: response } unless assistant

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
      Rails.logger.warn "[HALLUCINATION WARNING] Reasons: #{validation_result[:hallucination_risk][:reasons].join(', ')}"
      Rails.logger.warn "[HALLUCINATION WARNING] Response: #{response.truncate(200)}"
    end

    # API Usage'a kalite metriklerini ekle
    update_last_usage_quality_metrics(
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

  def update_last_usage_quality_metrics(assistant:, confidence:, hallucination_risk:, no_info_response:)
    return unless defined?(Saturn::ApiUsage)

    # Son kaydedilen usage'ı güncelle
    last_usage = Saturn::ApiUsage.where(
      saturn_assistant_id: assistant.id,
      api_type: 'chat'
    ).order(created_at: :desc).first

    return unless last_usage && last_usage.created_at > 10.seconds.ago

    last_usage.update(
      confidence: confidence.to_s,
      hallucination_risk: hallucination_risk.to_s,
      no_info_response: no_info_response
    )
  rescue StandardError => e
    Rails.logger.error "[API TRACKING] Failed to update quality metrics: #{e.message}"
  end

  def parse_citations(response, assistant)
    # SSS ve Döküman citation'larını çıkar
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

    # Citation isimlerini al
    citations = {}

    if doc_citations.any?
      documents = assistant.documents.where(id: doc_citations).index_by(&:id)
      doc_citations.each do |doc_id|
        citations["DOKÜMAN_#{doc_id}"] = documents[doc_id]&.name if documents[doc_id]
      end
    end

    if faq_citations.any?
      # SSS numaraları 1'den başlıyor, index olarak kullan
      faqs = assistant.responses.approved.limit(10).to_a
      faq_citations.each do |faq_num|
        faq = faqs[faq_num - 1]
        citations["SSS_#{faq_num}"] = faq&.question&.truncate(50) if faq
      end
    end

    # Yanıttan meta etiketleri temizle (kullanıcıya gösterme)
    cleaned_response = clean_response_tags(response, confidence_pattern)

    result = { content: cleaned_response }
    result[:additional_attributes] = { citations: citations } if citations.any?

    result
  end

  def create_conversation(message, content_params)
    return if content_params.blank?

    conversation = message.conversation
    message_attrs = {
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: assistant_for_message
    }

    # Merge additional_attributes if present
    message_attrs[:additional_attributes] = content_params[:additional_attributes] if content_params[:additional_attributes].present?

    conversation.messages.create!(
      content_params.except(:additional_attributes).merge(message_attrs)
    )
  end

  def assistant_for_message
    hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
  end

  def call_saturn(message)
    assistant = hook.account.saturn_assistants.find_by(id: hook.settings['assistant_id'])
    return 'Saturn assistant not found' unless assistant

    # Check for intent-based handoff before processing
    if assistant.handoff_config.present? && assistant.handoff_config['enabled']
      intent_detector = Saturn::IntentDetectionService.new(
        assistant: assistant,
        message_content: message.content
      )
      detected_intent = intent_detector.detect

      if detected_intent
        handoff_processor = Saturn::HandoffProcessorService.new(
          assistant: assistant,
          conversation: conversation,
          intent: detected_intent
        )
        return 'conversation_handoff' if handoff_processor.perform
      end
    end

    chat_service = Saturn::Llm::AssistantChatService.new(assistant: assistant)
    formatted_history = format_message_history(previous_messages)

    # Build message content with attachments (images, etc.)
    message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: message)
    user_message_content = message_builder.generate_content

    chat_service.create_ai_response(
      user_message: user_message_content,
      conversation_history: formatted_history
    )
  rescue StandardError => e
    Rails.logger.error("Saturn integration error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?
    'Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.'
  end

  def format_message_history(messages)
    messages.map do |msg|
      role_type = msg[:type].downcase == 'user' ? 'user' : 'assistant'
      { role: role_type, content: msg[:content] }
    end
  end

  def previous_messages
    previous_messages = []
    conversation.messages.where(message_type: [:outgoing, :incoming]).where(private: false).offset(1).find_each do |message|
      role = determine_role(message)

      # Build message content with attachments if available
      message_builder = Saturn::Llm::OpenAiMessageBuilderService.new(message: message)
      message_content = message_builder.generate_content

      # Skip if message has no content
      next if message_content.blank? || message_content == 'Message without content'

      previous_messages << { content: message_content, type: role }
    end
    previous_messages
  end

  def determine_role(message)
    message.message_type == 'incoming' ? 'User' : 'Bot'
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
