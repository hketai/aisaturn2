require 'openai'

class Saturn::Llm::AssistantChatService < Saturn::Llm::BaseOpenAiService
  def initialize(assistant: nil)
    super()
    @assistant = assistant
    initialize_message_history
  end

  def create_ai_response(user_message: nil, conversation_history: [], message_role: 'user')
    append_conversation_history(conversation_history)
    append_user_message(user_message, message_role) if user_message.present?
    
    # Debug: Log the system message to verify prompt is being used
    system_msg = @messages.find { |m| m[:role] == 'system' }
    Rails.logger.error("=== Saturn System Prompt ===")
    Rails.logger.error(system_msg[:content])
    Rails.logger.error("=== End System Prompt ===")
    Rails.logger.error("Total messages: #{@messages.length}")
    Rails.logger.error("Messages structure: #{@messages.map { |m| { role: m[:role], content_length: m[:content]&.length } }.inspect}")
    
    execute_chat_api(messages: @messages, temperature: get_temperature_setting)
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
    template_parts << build_description_section
    template_parts << build_guidelines_section
    template_parts << build_guardrails_section
    template_parts << build_faqs_section
    template_parts << build_documents_section
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
      - **Odaklan**: Kendi eğitim verilerini veya varsayımlarını kullanarak sorguları yanıtlama. Yanıtları yalnızca sağlanan bilgi ve bağlama dayandır.
      - **Netleştirme İste**: Belirsizlik olduğunda, varsayım yapmak yerine kısa netleştirme soruları sor.
      - **Doğal Akış**: Doğal bir şekilde etkileşimde bulun ve uygun olduğunda ilgili takip soruları sor. Konuşmanın akışını sürdür.
      - **Profesyonel Ton**: Konuşma boyunca profesyonel ama samimi bir ton koru.

      ## Yanıt Kuralları

      - Konuşmayı açıkça bitirmeye çalışma (örneğin, "Görüşürüz!" veya "Başka bir şeye ihtiyacın olursa haber ver" gibi ifadelerden kaçın).
      - Başka bir şeye ihtiyaçları olup olmadığını sorma (örneğin, "Başka nasıl yardımcı olabilirim?" gibi şeyler söyleme).
      - Mevcut bilgilere dayanarak yararlı bir yanıt sağlayamıyorsan, kullanıcıyı nazikçe bilgilendir ve alternatif seçenekler öner.
    INSTRUCTIONS
  end

  def build_assistant_introduction
    "## Kimliğin\n\nSen #{@assistant.name}, yardımcı bir AI asistanısın."
  end

  def build_description_section
    return nil unless @assistant.description.present?
    "## Açıklama\n\n#{@assistant.description}"
  end

  def build_guidelines_section
    return nil unless @assistant.response_guidelines.present?
    guidelines_text = "## Yanıt Kuralları\n\nYanıtların şu kurallara uymalı:\n"
    @assistant.response_guidelines.each do |guideline|
      guidelines_text += "- #{guideline}\n"
    end
    guidelines_text
  end

  def build_guardrails_section
    return nil unless @assistant.guardrails.present?
    guardrails_text = "## Sınırlar\n\nBu sınırlara her zaman saygı göster:\n"
    @assistant.guardrails.each do |guardrail|
      guardrails_text += "- #{guardrail}\n"
    end
    guardrails_text
  end

  def build_faqs_section
    faqs = @assistant.responses.approved.limit(50)
    return nil if faqs.empty?

    faqs_text = "## Sık Sorulan Sorular (FAQ)\n\n"
    faqs_text += "Aşağıdaki sorular ve cevapları kullanarak kullanıcılara yardımcı ol. Bu bilgileri referans al:\n\n"
    
    faqs.each_with_index do |faq, index|
      faqs_text += "#{index + 1}. **Soru**: #{faq.question}\n"
      faqs_text += "   **Cevap**: #{faq.answer}\n\n"
    end
    
    faqs_text
  end

  def build_documents_section
    documents = @assistant.documents.available.limit(10)
    return nil if documents.empty?

    docs_text = "## Referans Dökümanlar\n\n"
    docs_text += "Aşağıdaki dökümanlardaki bilgileri kullanarak kullanıcılara yardımcı ol. Bu bilgileri referans al:\n\n"
    
    documents.each_with_index do |doc, index|
      docs_text += "### #{index + 1}. #{doc.name}\n"
      if doc.content.present?
        # İlk 2000 karakteri al (token limiti için)
        content_preview = doc.content.first(2000)
        docs_text += "#{content_preview}\n\n"
      end
    end
    
    docs_text
  end

  def append_conversation_history(history)
    return unless history.present?
    
    # Filter out any system messages from history to avoid duplicates
    # System message should only be the one we created in initialize_message_history
    filtered_history = history.reject { |msg| msg[:role] == 'system' || msg['role'] == 'system' }
    @messages += filtered_history
  end

  def append_user_message(message, role)
    # Message can be a string or an array (for multi-part messages with images)
    @messages << { role: role, content: message }
  end

  def get_temperature_setting
    @assistant&.temperature
  end
end
