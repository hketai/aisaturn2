# Incoming Message Service for WhatsApp Web
# Processes messages received from WhatsApp Web client
class WhatsappWeb::IncomingMessageService
  pattr_initialize [:channel!, :message_data!]

  def perform
    return unless message_data.present?

    # Filter out unwanted messages (additional check in case Node.js filter missed something)
    return if should_ignore_message?

    # Check if inbox exists, if not, log error and return
    unless channel.inbox.present?
      Rails.logger.error "[WHATSAPP_WEB] Inbox not found for channel #{channel.id}. Message cannot be processed."
      return
    end

    set_contact
    return unless @contact

    ActiveRecord::Base.transaction do
      set_conversation
      create_message
      attach_files if message_data[:attachments].present?
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Error processing message: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}" if Rails.env.development?
    raise
  end

  private

  def should_ignore_message?
    from = message_data[:from].to_s
    
    # 1. Group messages have @g.us suffix
    return true if from.include?('@g.us')
    
    # 2. Status messages
    return true if from == 'status@broadcast' || message_data[:is_status] == true
    
    # 3. System/notification messages
    return true if message_data[:is_notification] == true || message_data[:type] == 'notification'
    
    # 4. Protocol/system messages
    return true if %w[protocol system].include?(message_data[:type].to_s)
    
    # 5. Empty messages without media (likely system messages)
    if message_data[:body].blank? && message_data[:attachments].blank? && !from.include?('@g.us')
      return true
    end
    
    false
  end

  def set_contact
    phone_number = normalize_phone_number(message_data[:from])
    return if phone_number.blank?

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
    @message = @conversation.messages.create!(
      content: message_data[:body] || message_data[:caption],
      account_id: channel.account_id,
      inbox_id: channel.inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message_data[:id].to_s,
      content_type: determine_content_type
    )
  end

  def attach_files
    message_data[:attachments].each do |attachment_data|
      attachment = @message.attachments.new(
        account_id: channel.account_id,
        file_type: determine_file_type(attachment_data[:mimetype]),
        external_url: attachment_data[:url]
      )

      # Download and attach file if URL is provided
      if attachment_data[:url].present?
        download_and_attach_file(attachment, attachment_data)
      end

      attachment.save!
    end
  end

  def download_and_attach_file(attachment, attachment_data)
    file = Down.download(attachment_data[:url])
    attachment.file.attach(
      io: file,
      filename: attachment_data[:filename] || file.original_filename,
      content_type: attachment_data[:mimetype] || file.content_type
    )
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] File download error: #{e.message}"
  end

  def normalize_phone_number(phone)
    return nil if phone.blank?

    # Group messages are already filtered out, so we only process individual messages
    # Normalize to E.164 format
    # Remove WhatsApp suffixes (@s.whatsapp.net, @c.us, etc.)
    phone = phone.to_s.gsub(/@[^.]+\.(whatsapp\.net|c\.us)/, '')
    
    # Remove any remaining non-digit characters except +
    phone = phone.gsub(/[^\d+]/, '')
    
    # Ensure phone number starts with +
    phone = phone.start_with?('+') ? phone : "+#{phone}"
    
    # Validate E.164 format (should start with + and contain only digits after)
    return nil unless phone.match?(/^\+\d{1,15}$/)
    
    phone
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

