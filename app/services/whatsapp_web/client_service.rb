# WhatsApp Web Client Service
# Manages whatsapp-web.js client lifecycle
class WhatsappWeb::ClientService
  pattr_initialize [:channel!]

  def initialize_client
    # This will be called by a background job that runs Node.js
    # For now, we'll create a job to handle this
    WhatsappWeb::InitializeClientJob.perform_later(channel.id)
  end

  def start_client
    # Start WhatsApp Web client via Node.js service
    # This will be handled by a separate Node.js process/service
    WhatsappWeb::NodeService.new(channel: channel).start_client
  end

  def stop_client
    # Stop WhatsApp Web client
    WhatsappWeb::NodeService.new(channel: channel).stop_client
  end

  def get_qr_code
    # Get QR code for authentication
    WhatsappWeb::NodeService.new(channel: channel).get_qr_code
  end

  def send_message(phone_number, message_content, attachments: [])
    # Send message via WhatsApp Web
    WhatsappWeb::NodeService.new(channel: channel).send_message(phone_number, message_content, attachments)
  end

  def get_client_status
    # Get current client status
    WhatsappWeb::NodeService.new(channel: channel).get_status
  end
end

