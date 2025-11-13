# Send Message Service for WhatsApp Web
class WhatsappWeb::SendOnWhatsappWebService < Base::SendOnChannelService
  private

  def channel_class
    Channel::WhatsappWeb
  end

  def perform_reply
    Rails.logger.info "[WHATSAPP_WEB] Starting send message for message ID: #{message.id}"
    source_id = message.conversation.contact_inbox.source_id
    
    phone_number = normalize_phone_number_for_whatsapp(source_id)
    Rails.logger.info "[WHATSAPP_WEB] Normalized phone number: #{phone_number} (original: #{source_id})"
    attachments = build_attachments

    result = channel.send_message(phone_number, message.outgoing_content, attachments: attachments)
    Rails.logger.info "[WHATSAPP_WEB] Send message result: #{result.inspect}"

    if result[:success]
      # Update source_id and mark as delivered (WhatsApp Web sends messages immediately to server)
      update_params = {}
      update_params[:source_id] = result[:message_id] if result[:message_id].present?
      update_params[:status] = :delivered
      
      message.update!(update_params) if update_params.any?
      Rails.logger.info "[WHATSAPP_WEB] Message #{message.id} updated: source_id=#{result[:message_id]}, status=delivered"
    else
      message.update!(
        status: :failed,
        external_error: result[:error] || 'Failed to send message'
      )
    end
  end

  def build_attachments
    return [] unless message.attachments.any?

    message.attachments.map do |attachment|
      {
        url: attachment.download_url,
        filename: attachment.file.filename.to_s,
        mimetype: attachment.file.content_type,
        type: map_file_type(attachment.file_type)
      }
    end
  end

  def map_file_type(file_type)
    case file_type.to_s
    when 'image'
      'image'
    when 'audio'
      'audio'
    when 'video'
      'video'
    when 'file', 'document'
      'document'
    else
      'document'
    end
  end

  def normalize_phone_number_for_whatsapp(phone)
    return nil if phone.blank?

    # Group messages are already filtered out, so we only process individual messages
    # Remove + prefix if present
    phone = phone.to_s.gsub(/^\+/, '')
    
    # Remove any non-digit characters
    phone = phone.gsub(/\D/, '')
    
    # Add @c.us suffix for WhatsApp Web format
    phone = "#{phone}@c.us"
    
    phone
  end
end

