# Node.js Service for WhatsApp Web
# Communicates with Node.js process running whatsapp-web.js
require 'httparty'

class WhatsappWeb::NodeService
  pattr_initialize [:channel!]

  NODE_SERVICE_URL = ENV.fetch('WHATSAPP_WEB_NODE_SERVICE_URL', 'http://localhost:3001').freeze

  def start_client
    # Convert channel.id to string for Node.js service
    channel_id_str = channel.id.to_s
    Rails.logger.info "[WHATSAPP_WEB] Starting client for channel #{channel_id_str}"
    
    response = HTTParty.post(
      "#{NODE_SERVICE_URL}/client/start",
      headers: { 'Content-Type' => 'application/json' },
      body: {
        channel_id: channel_id_str,
        auth_data: channel.auth_data,
        cache_data: load_cache_if_exists
      }.to_json,
      timeout: 30
    )

    Rails.logger.info "[WHATSAPP_WEB] Start client response: #{response.code} - #{response.parsed_response.inspect}"
    handle_response(response)
  rescue Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error "[WHATSAPP_WEB] Node.js service not available: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Please start the Node.js service at #{NODE_SERVICE_URL}"
    channel.update!(status: 'disconnected')
    raise StandardError, "WhatsApp Web Node.js servisi çalışmıyor. Lütfen servisi başlatın: #{NODE_SERVICE_URL}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Start client error: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(5).join("\n")}" if Rails.env.development?
    channel.update!(status: 'disconnected')
    raise
  end

  def stop_client
    # Convert channel.id to string for Node.js service
    channel_id_str = channel.id.to_s
    HTTParty.post(
      "#{NODE_SERVICE_URL}/client/stop",
      headers: { 'Content-Type' => 'application/json' },
      body: { channel_id: channel_id_str }.to_json,
      timeout: 10
    )
  rescue Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error "[WHATSAPP_WEB] Node.js service not available: #{e.message}"
    # Don't raise error for stop, just log it
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Stop client error: #{e.message}"
  end

  def get_qr_code
    # Convert channel.id to string for Node.js service
    channel_id_str = channel.id.to_s
    Rails.logger.info "[WHATSAPP_WEB] Getting QR code for channel #{channel_id_str}"
    
    response = HTTParty.get(
      "#{NODE_SERVICE_URL}/client/#{channel_id_str}/qr",
      headers: { 'Content-Type' => 'application/json' },
      timeout: 10
    )

    Rails.logger.info "[WHATSAPP_WEB] QR code response status: #{response.code}, body: #{response.parsed_response.inspect}"

    if response.success?
      qr_data = response.parsed_response
      {
        qr_code: qr_data['qr_code'] || qr_data[:qr_code],
        expires_at: qr_data['expires_at'] || qr_data[:expires_at]
      }
    else
      Rails.logger.warn "[WHATSAPP_WEB] QR code not available: #{response.code} - #{response.parsed_response.inspect}"
      nil
    end
  rescue Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error "[WHATSAPP_WEB] Node.js service not available: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Get QR code error: #{e.class.name}: #{e.message}"
    Rails.logger.error "[WHATSAPP_WEB] Backtrace: #{e.backtrace.first(5).join("\n")}" if Rails.env.development?
    nil
  end

  def send_message(phone_number, message_content, attachments = [])
    # Convert channel.id to string for Node.js service
    channel_id_str = channel.id.to_s
    response = HTTParty.post(
      "#{NODE_SERVICE_URL}/client/#{channel_id_str}/send-message",
      headers: { 'Content-Type' => 'application/json' },
      body: {
        to: phone_number,
        message: message_content,
        attachments: attachments
      }.to_json,
      timeout: 30
    )

    handle_send_response(response)
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Send message error: #{e.message}"
    raise
  end

  def get_status
    # Convert channel.id to string for Node.js service
    channel_id_str = channel.id.to_s
    response = HTTParty.get(
      "#{NODE_SERVICE_URL}/client/#{channel_id_str}/status",
      headers: { 'Content-Type' => 'application/json' },
      timeout: 5
    )

    response.parsed_response if response.success?
  rescue Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error "[WHATSAPP_WEB] Node.js service not available: #{e.message}"
    { status: channel.status, phone_number: channel.phone_number, error: 'Node.js servisi çalışmıyor' }
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Get status error: #{e.message}"
    { status: channel.status, phone_number: channel.phone_number, error: e.message }
  end

  def save_auth_data(auth_data)
    # Save auth data to channel
    storage_service = WhatsappWeb::StorageService.new(channel: channel)
    storage_service.save_auth_data(auth_data)
  end

  def save_cache_data(cache_data)
    # Save cache data to Object Storage
    storage_service = WhatsappWeb::StorageService.new(channel: channel)
    storage_service.save_cache_data(cache_data)
  end

  private

  def load_cache_if_exists
    storage_service = WhatsappWeb::StorageService.new(channel: channel)
    storage_service.load_cache_data
  end

  def handle_response(response)
    if response.success?
      data = response.parsed_response
      update_channel_status(data['status'])
      
      # Save auth data if provided
      save_auth_data(data['auth_data']) if data['auth_data'].present?
      
      # Save cache data if provided
      save_cache_data(data['cache_data']) if data['cache_data'].present?
      
      data
    else
      error_message = response.parsed_response&.dig('error') || 'Unknown error'
      Rails.logger.error "[WHATSAPP_WEB] API error: #{error_message}"
      channel.update!(status: 'disconnected')
      raise StandardError, error_message
    end
  end

  def handle_send_response(response)
    if response.success?
      data = response.parsed_response
      {
        message_id: data['message_id'],
        success: true
      }
    else
      error_message = response.parsed_response&.dig('error') || 'Unknown error'
      {
        success: false,
        error: error_message
      }
    end
  end

  def update_channel_status(status)
    channel.update!(status: status) if Channel::WhatsappWeb::STATUSES.include?(status)
  end
end

