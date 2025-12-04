# Incoming Message Service for WhatsApp Web
# Processes messages received from WhatsApp Web client
require 'base64'
require 'stringio'

class WhatsappWeb::IncomingMessageService
  pattr_initialize [:channel!, :message_data!]

  def perform
    Rails.logger.info '[WHATSAPP_WEB] ===== INCOMING MESSAGE SERVICE START ====='
    Rails.logger.info "[WHATSAPP_WEB] Channel ID: #{channel.id}"
    Rails.logger.info "[WHATSAPP_WEB] Message ID: #{message_data[:id]}"
    Rails.logger.info "[WHATSAPP_WEB] From: #{message_data[:from]}"
    Rails.logger.info "[WHATSAPP_WEB] To: #{message_data[:to]}"
    Rails.logger.info "[WHATSAPP_WEB] FromMe: #{message_data[:fromMe]} (#{message_data[:fromMe].class})"
    Rails.logger.info "[WHATSAPP_WEB] Type: #{message_data[:type]}"
    Rails.logger.info "[WHATSAPP_WEB] Body: #{message_data[:body]&.first(50)}"
    Rails.logger.info "[WHATSAPP_WEB] Full message_data keys: #{message_data.keys.inspect}"

    return unless message_data.present?

    # Filter out unwanted messages (additional check in case Node.js filter missed something)
    if should_ignore_message?
      Rails.logger.info '[WHATSAPP_WEB] ⚠️ Message ignored by should_ignore_message? check'
      return
    end

    # Check if inbox exists, if not, log error and return
    unless channel.inbox.present?
      Rails.logger.error "[WHATSAPP_WEB] ❌ Inbox not found for channel #{channel.id}. Message cannot be processed."
      return
    end

    set_contact
    unless @contact
      Rails.logger.error '[WHATSAPP_WEB] ❌ Contact could not be set'
      return
    end

    Rails.logger.info "[WHATSAPP_WEB] Contact set: ID=#{@contact.id}, name=#{@contact.name}"

    ActiveRecord::Base.transaction do
      set_conversation
      Rails.logger.info "[WHATSAPP_WEB] Conversation set: ID=#{@conversation.id}"

      create_message
      Rails.logger.info "[WHATSAPP_WEB] Message created: ID=#{@message.id}" if @message

      attach_files if message_data[:attachments].present?
    end

    Rails.logger.info '[WHATSAPP_WEB] ===== INCOMING MESSAGE SERVICE SUCCESS ====='
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] ❌ ERROR processing message: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}" if Rails.env.development?
    raise
  end

  private

  def should_ignore_message?
    from = message_data[:from].to_s
    from_me = message_data[:fromMe] == true || message_data[:fromMe] == 'true'
    to = message_data[:to].to_s

    Rails.logger.info "[WHATSAPP_WEB] should_ignore_message? check: from=#{from}, to=#{to}, fromMe=#{from_me}, type=#{message_data[:type]}, body=#{message_data[:body]&.first(30)}"

    # Mobilden gönderilen mesajlar (fromMe=true) için özel kontrol
    # Bu mesajlar panele gelmeli, sadece panel'den gönderilen mesajlar duplicate olarak filtrelenmeli
    if from_me
      Rails.logger.info '[WHATSAPP_WEB] fromMe=true detected, allowing message through (will be checked for duplicates in create_message)'
      return false # Mobilden gönderilen mesajları geçir
    end

    # 1. Group messages have @g.us suffix
    return true if from.include?('@g.us')

    # 2. Status messages
    return true if from == 'status@broadcast' || message_data[:is_status] == true

    # 3. System/notification messages
    return true if message_data[:is_notification] == true || message_data[:type] == 'notification'

    # 4. Protocol/system messages
    return true if %w[protocol system].include?(message_data[:type].to_s)

    # 5. Empty messages without media (likely system messages)
    # BUT: Allow media messages, stickers, and contact cards even if body is empty
    is_sticker = message_data[:is_sticker] == true || message_data[:type] == 'sticker'
    is_contact_card = message_data[:is_contact_card] == true || %w[vcard multi_vcard].include?(message_data[:type].to_s)
    return true if message_data[:body].blank? && message_data[:attachments].blank? && !is_sticker && !is_contact_card && !from.include?('@g.us')

    # 6. Messages from broadcast lists
    return true if from == 'status@broadcast'

    false
  end

  def set_contact
    Rails.logger.info "[WHATSAPP_WEB] Setting contact: from=#{message_data[:from]}, to=#{message_data[:to]}, fromMe=#{message_data[:fromMe]}"

    phone_number = normalized_counterpart_number
    Rails.logger.info "[WHATSAPP_WEB] Normalized counterpart phone number: #{phone_number}"

    if phone_number.blank?
      Rails.logger.error '[WHATSAPP_WEB] ❌ Counterpart phone number is blank after normalization'
      return
    end

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: channel.inbox,
      contact_attributes: {
        name: message_data[:contact_name] || phone_number,
        phone_number: phone_number
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    Rails.logger.info "[WHATSAPP_WEB] Contact set: ID=#{@contact.id}, name=#{@contact.name}, phone=#{@contact.phone_number}"
  end

  def set_conversation
    @conversation = if channel.inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def create_message
    message_source_id = message_data[:id].to_s
    from_me = message_originates_from_channel?

    Rails.logger.info "[WHATSAPP_WEB] Creating message: source_id=#{message_source_id}, fromMe=#{from_me}, from=#{message_data[:from]}, to=#{message_data[:to]}"

    # KATMAN 1: ExternalID kontrolü (en hızlı - WhatsApp message ID ile kontrol)
    # Panel'den gönderilen mesajların source_id'si WhatsApp message ID olarak kaydedilir
    existing_message = @conversation.messages.find_by(source_id: message_source_id)
    if existing_message
      Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 1: Message #{message_source_id} already exists (externalId match), skipping duplicate"
      @message = existing_message
      return
    end

    # KATMAN 2: Panel'den gönderilen mesaj kontrolü (outgoing messages)
    # Panel'den gönderilen mesajlar outgoing olarak kaydedilir ve source_id'leri WhatsApp message ID'dir
    panel_message = channel.inbox.messages.outgoing.find_by(source_id: message_source_id)
    if panel_message
      Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 2: Message #{message_source_id} is a panel-sent message (outgoing with same source_id), skipping"
      @message = panel_message
      return
    end

    # KATMAN 3: fromMe=true mesajlar için race condition koruması
    # Bazen panel'den mesaj gönderilir ama source_id henüz kaydedilmemiş olabilir
    # Bu durumda sadece source_id kontrolü yapıyoruz (içerik kontrolü yapmıyoruz çünkü telefondan gönderilen mesajlar farklı içerikli olabilir)
    if from_me
      Rails.logger.info '[WHATSAPP_WEB] fromMe=true detected, checking for recent duplicate (race condition protection)...'

      # Son 3 saniye içinde source_id'si olmayan outgoing mesaj var mı?
      # Bu, panel'den gönderilmiş ama source_id henüz kaydedilmemiş mesaj olabilir
      # NOT: İçerik kontrolü yapmıyoruz çünkü telefondan gönderilen mesajlar farklı içerikli olabilir
      three_seconds_ago = 3.seconds.ago
      recent_duplicate = @conversation.messages
                                      .where('created_at >= ?', three_seconds_ago)
                                      .where(message_type: :outgoing)
                                      .where(source_id: nil) # Sadece source_id'si olmayan mesajları kontrol et
                                      .order(created_at: :desc) # En yeni mesajı al
                                      .first

      if recent_duplicate
        Rails.logger.info "[WHATSAPP_WEB] ⚠️ KATMAN 3: Found recent duplicate (race condition): message_id=#{recent_duplicate.id}, content=#{recent_duplicate.content&.first(30)}"

        # Panel'den gönderilen mesajın source_id'sini güncelle (race condition fix)
        if message_source_id.present?
          recent_duplicate.update_column(:source_id, message_source_id)
          Rails.logger.info "[WHATSAPP_WEB] ✅ Updated recent message source_id: #{message_source_id}"
        end

        @message = recent_duplicate
        return
      end

      # fromMe=true ama duplicate yok → Bu mesaj DOĞRUDAN TELEFONDAN gönderilmiş
      Rails.logger.info '[WHATSAPP_WEB] ✅ fromMe=true but no duplicate found - this is a phone-sent message'
    end

    # Tüm kontroller geçildi → Yeni mesaj oluştur
    Rails.logger.info "[WHATSAPP_WEB] ✅ Creating new incoming message (fromMe=#{from_me})"

    message_params = {
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      message_type: from_me ? :outgoing : :incoming,
      sender: from_me ? outgoing_sender : @contact,
      source_id: message_source_id,
      content_type: determine_content_type
    }

    # Handle different message types
    if message_data[:is_sticker] || message_data[:type] == 'sticker'
      message_params[:content] = '🎨 Sticker'
      message_params[:content_attributes] = { 'is_sticker' => true }
      Rails.logger.info '[WHATSAPP_WEB] 🎨 Processing sticker message'
    elsif message_data[:is_contact_card] || %w[vcard multi_vcard].include?(message_data[:type].to_s)
      contact_cards = message_data[:contact_cards] || []
      message_params[:content] = build_contact_card_content(contact_cards)
      message_params[:content_attributes] = { 'contact_cards' => contact_cards, 'is_contact_card' => true }
      Rails.logger.info "[WHATSAPP_WEB] 👤 Processing contact card: #{contact_cards.size} contacts"
    else
      message_params[:content] = message_data[:body] || message_data[:caption]
    end

    @message = @conversation.messages.create!(message_params)

    Rails.logger.info "[WHATSAPP_WEB] ✅ Created message: ID=#{@message.id}, type=#{@message.message_type}, source_id=#{message_source_id}, from=#{message_data[:from]}, to=#{message_data[:to]}, fromMe=#{from_me}"
  end

  def build_contact_card_content(contact_cards)
    return '👤 Contact Card' if contact_cards.blank?

    contacts = contact_cards.map do |card|
      card = card.with_indifferent_access if card.respond_to?(:with_indifferent_access)
      name = card[:name] || card['name'] || 'Unknown'
      phone = card[:phone] || card['phone']
      phone_text = phone.present? ? " (#{phone})" : ''
      "👤 #{name}#{phone_text}"
    end

    contacts.join("\n")
  end

  def attach_files
    message_data[:attachments].each do |raw_attachment|
      attachment_data = raw_attachment.respond_to?(:to_unsafe_h) ? raw_attachment.to_unsafe_h : raw_attachment
      attachment_data = attachment_data.with_indifferent_access

      attachment = @message.attachments.new(
        account_id: channel.account_id,
        file_type: determine_file_type(attachment_data[:mimetype])
      )

      if attachment_data[:url].present?
        attachment.external_url = attachment_data[:url]
        attach_from_url(attachment, attachment_data)
      elsif attachment_data[:data].present?
        attach_from_base64(attachment, attachment_data)
      else
        Rails.logger.info "[WHATSAPP_WEB] Attachment skipped - no url or data provided"
      end

      attachment.save!
    end
  end

  def attach_from_url(attachment, attachment_data)
    file = Down.download(attachment_data[:url])
    attachment.file.attach(
      io: file,
      filename: attachment_data[:filename] || file.original_filename,
      content_type: attachment_data[:mimetype] || file.content_type
    )
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] File download error: #{e.message}"
  end

  def attach_from_base64(attachment, attachment_data)
    payload = attachment_data[:data].to_s.split(',').last
    decoded = Base64.decode64(payload)
    io = StringIO.new(decoded)
    attachment.file.attach(
      io: io,
      filename: attachment_data[:filename] || default_filename_for(attachment_data[:mimetype]),
      content_type: attachment_data[:mimetype] || 'application/octet-stream'
    )
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Inline attachment error: #{e.message}"
  end

  def default_filename_for(mimetype)
    return 'whatsapp-attachment' if mimetype.blank?

    extension = mimetype.split('/').last
    return 'whatsapp-attachment' if extension.blank?

    "whatsapp-attachment.#{extension}"
  end

  def normalize_phone_number(phone)
    Rails.logger.info "[WHATSAPP_WEB] Normalizing phone: #{phone.inspect}"

    return nil if phone.blank?

    original_phone = phone.to_s.dup

    # Group messages are already filtered out, so we only process individual messages
    # Normalize to E.164 format
    # Remove WhatsApp suffixes (@s.whatsapp.net, @c.us, etc.)
    phone = phone.to_s.gsub(/@[^.]+\.(whatsapp\.net|c\.us)/, '')
    Rails.logger.info "[WHATSAPP_WEB] After removing suffix: #{phone}"

    # Remove any remaining non-digit characters except +
    phone = phone.gsub(/[^\d+]/, '')
    Rails.logger.info "[WHATSAPP_WEB] After removing non-digits: #{phone}"

    # Ensure phone number starts with +
    phone = phone.start_with?('+') ? phone : "+#{phone}"
    Rails.logger.info "[WHATSAPP_WEB] After adding +: #{phone}"

    # Validate E.164 format (should start with + and contain only digits after)
    unless phone.match?(/^\+\d{1,15}$/)
      Rails.logger.error "[WHATSAPP_WEB] ❌ Invalid E.164 format: #{phone} (original: #{original_phone})"
      return nil
    end

    Rails.logger.info "[WHATSAPP_WEB] ✅ Final normalized phone: #{phone} (original: #{original_phone})"
    phone
  end

  def normalized_counterpart_number
    raw_number = if message_originates_from_channel?
                   message_data[:to]
                 else
                   message_data[:from]
                 end

    Rails.logger.info "[WHATSAPP_WEB] Determined raw counterpart number: #{raw_number}"
    normalize_phone_number(raw_number)
  end

  def message_originates_from_channel?
    message_data[:fromMe] == true || message_data[:fromMe].to_s == 'true'
  end

  def outgoing_sender
    @outgoing_sender ||= channel.account.users.order(:id).first
  end

  def determine_content_type
    return 'text' if message_data[:type] == 'text'
    return 'image' if message_data[:type] == 'image'
    return 'audio' if message_data[:type] == 'audio'
    return 'video' if message_data[:type] == 'video'
    return 'document' if message_data[:type] == 'document'
    return 'location' if message_data[:type] == 'location'

    'text'
  end

  def determine_file_type(mimetype)
    return :image if mimetype&.start_with?('image/')
    return :audio if mimetype&.start_with?('audio/')
    return :video if mimetype&.start_with?('video/')

    :file
  end

  def conversation_params
    {
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      status: :open
    }
  end
end
