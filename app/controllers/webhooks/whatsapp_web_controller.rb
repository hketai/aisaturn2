# Webhook Controller for WhatsApp Web
# Receives events from Node.js service
class Webhooks::WhatsappWebController < ActionController::API
  def process_payload
    channel = find_channel
    return head :not_found unless channel

    case params[:event_type]
    when 'message'
      process_message(channel, params[:message_data])
    when 'qr'
      process_qr_code(channel, params[:qr_data])
    when 'ready'
      process_ready(channel)
    when 'disconnected'
      process_disconnected(channel)
    when 'auth_failure'
      process_auth_failure(channel)
    when 'message_ack'
      process_message_ack(channel, params[:message_id], params[:status])
    end

    head :ok
  end

  private

  def find_channel
    Channel::WhatsappWeb.find_by(id: params[:channel_id])
  end

  def process_message(channel, message_data)
    Rails.logger.info '[WHATSAPP_WEB] ===== WEBHOOK: MESSAGE RECEIVED ====='
    Rails.logger.info "[WHATSAPP_WEB] Channel ID: #{channel.id}"
    Rails.logger.info "[WHATSAPP_WEB] Message ID: #{message_data[:id]}"
    Rails.logger.info "[WHATSAPP_WEB] From: #{message_data[:from]}"
    Rails.logger.info "[WHATSAPP_WEB] FromMe: #{message_data[:fromMe]}"
    Rails.logger.info "[WHATSAPP_WEB] Type: #{message_data[:type]}"
    Rails.logger.info "[WHATSAPP_WEB] Body: #{message_data[:body]&.first(50)}"

    WhatsappWeb::IncomingMessageService.new(
      channel: channel,
      message_data: message_data
    ).perform

    Rails.logger.info '[WHATSAPP_WEB] ===== WEBHOOK: MESSAGE PROCESSED SUCCESSFULLY ====='
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] ❌ WEBHOOK ERROR: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  def process_qr_code(channel, qr_data)
    # Store QR code temporarily (we'll fetch it from Node.js service)
    # Update channel status to connecting
    channel.update!(
      status: 'connecting',
      qr_code_expires_at: qr_data[:expires_at] ? Time.zone.parse(qr_data[:expires_at]) : 2.minutes.from_now
    )
    Rails.logger.info "[WHATSAPP_WEB] QR code received for channel #{channel.id}"
  end

  def process_ready(channel)
    phone_number = params[:phone_number] || params['phone_number']
    Rails.logger.info "[WHATSAPP_WEB] Ready event received for channel #{channel.id}, phone_number param: #{phone_number.inspect}"
    Rails.logger.info "[WHATSAPP_WEB] All params keys: #{params.keys.inspect}"
    
    # Format phone number: ensure it starts with +
    formatted_phone = if phone_number.present?
                        phone_number.to_s.start_with?('+') ? phone_number.to_s : "+#{phone_number}"
                      else
                        nil
                      end
    
    Rails.logger.info "[WHATSAPP_WEB] Formatted phone_number: #{formatted_phone.inspect}"
    
    channel.update!(
      status: 'connected',
      phone_number: formatted_phone
    )

    # Create inbox now that connection is established
    create_inbox_for_channel(channel)
    
    Rails.logger.info "[WHATSAPP_WEB] Channel #{channel.id} updated with phone_number: #{channel.phone_number}"
  end

  def create_inbox_for_channel(channel)
    # Check if inbox already exists
    return if channel.inbox.present?

    # Get inbox name from provider_config
    inbox_name = channel.provider_config&.dig('pending_inbox_name') || "WhatsApp Web #{channel.phone_number}"

    # Create inbox
    inbox = channel.account.inboxes.create!(
      name: inbox_name,
      channel: channel
    )

    # Remove pending_inbox_name from provider_config
    channel.update!(provider_config: (channel.provider_config || {}).except('pending_inbox_name'))

    Rails.logger.info "[WHATSAPP_WEB] Inbox #{inbox.id} created for channel #{channel.id}"
  end

  def process_disconnected(channel)
    channel.update!(status: 'disconnected')
  end

  def process_auth_failure(channel)
    channel.update!(status: 'disconnected')
    channel.prompt_reauthorization!
  end

  def process_message_ack(channel, message_id, status)
    return unless channel.inbox.present?
    return unless message_id.present?
    return unless %w[delivered read].include?(status.to_s)

    # Find message by source_id
    message = channel.inbox.messages.find_by(source_id: message_id)
    return unless message

    # Update message status
    Messages::StatusUpdateService.new(message, status).perform
    Rails.logger.info "[WHATSAPP_WEB] Message #{message.id} status updated to #{status} (source_id: #{message_id})"
  end
end
