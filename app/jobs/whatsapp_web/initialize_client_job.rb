class WhatsappWeb::InitializeClientJob < ApplicationJob
  queue_as :default

  def perform(channel_id)
    channel = Channel::WhatsappWeb.find(channel_id)
    WhatsappWeb::ClientService.new(channel: channel).start_client
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "[WHATSAPP_WEB] Channel not found: #{channel_id}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Initialize client error: #{e.message}"
    channel&.update!(status: 'disconnected')
    raise
  end
end

