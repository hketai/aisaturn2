# WhatsApp Web Recovery Job
# Checks all WhatsApp Web channels and restarts disconnected clients
# Runs every 10 minutes via sidekiq-cron
class WhatsappWeb::RecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Rails.logger.info '[WHATSAPP_WEB_RECOVERY] Starting recovery check...'

    channels = Channel::WhatsappWeb.where.not(phone_number: nil)
    Rails.logger.info "[WHATSAPP_WEB_RECOVERY] Found #{channels.count} channels to check"

    channels.find_each do |channel|
      check_and_recover_channel(channel)
    end

    Rails.logger.info '[WHATSAPP_WEB_RECOVERY] Recovery check completed'
  end

  private

  def check_and_recover_channel(channel)
    node_status = WhatsappWeb::NodeService.new(channel: channel).get_status

    rails_status = channel.status
    node_connected = node_status && node_status['status'] == 'connected'

    Rails.logger.info "[WHATSAPP_WEB_RECOVERY] Channel #{channel.id}: Rails=#{rails_status}, Node=#{node_connected ? 'connected' : 'disconnected'}"

    # Eğer channel'ın phone_number'ı varsa (daha önce bağlanmış) ama Node.js'de client yoksa, yeniden başlat
    if channel.phone_number.present? && !node_connected
      Rails.logger.info "[WHATSAPP_WEB_RECOVERY] Channel #{channel.id}: Restarting client..."

      begin
        WhatsappWeb::NodeService.new(channel: channel).start_client
        Rails.logger.info "[WHATSAPP_WEB_RECOVERY] Channel #{channel.id}: Client restarted successfully"
      rescue StandardError => e
        Rails.logger.error "[WHATSAPP_WEB_RECOVERY] Channel #{channel.id}: Failed to restart - #{e.message}"
        channel.update!(status: 'disconnected')
      end
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB_RECOVERY] Error checking channel #{channel.id}: #{e.message}"
  end
end

