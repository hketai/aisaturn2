# == Schema Information
#
# Table name: channel_whatsapp_webs
#
#  id                  :bigint           not null, primary key
#  auth_data_encrypted :text
#  cache_storage_path  :string
#  phone_number        :string
#  provider_config     :jsonb
#  qr_code_expires_at  :datetime
#  qr_code_token       :string
#  status              :string           default("disconnected")
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_channel_whatsapp_webs_on_account_id     (account_id)
#  index_channel_whatsapp_webs_on_phone_number   (phone_number) UNIQUE
#  index_channel_whatsapp_webs_on_qr_code_token  (qr_code_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class Channel::WhatsappWeb < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp_webs'
  EDITABLE_ATTRS = [:phone_number, { provider_config: {} }].freeze

  STATUSES = %w[disconnected connecting connected disconnected_qr_expired].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :phone_number, uniqueness: true, allow_nil: true

  # Encrypt auth data if encryption is configured
  if Chatwoot.encryption_configured?
    encrypts :auth_data_encrypted
  end

  before_validation :generate_qr_code_token, on: :create
  # Don't auto-initialize - let frontend call start endpoint
  # after_create :initialize_whatsapp_client, if: -> { Rails.env != 'test' }
  before_destroy :cleanup_storage

  def name
    'WhatsApp Web'
  end

  def connected?
    status == 'connected'
  end

  def qr_code_expired?
    qr_code_expires_at.present? && qr_code_expires_at < Time.current
  end

  def generate_new_qr_code
    update!(
      qr_code_token: SecureRandom.hex(32),
      qr_code_expires_at: 2.minutes.from_now,
      status: 'connecting'
    )
  end

  def auth_data
    return nil if auth_data_encrypted.blank?

    JSON.parse(auth_data_encrypted)
  rescue JSON::ParserError
    nil
  end

  def auth_data=(data)
    self.auth_data_encrypted = data.is_a?(String) ? data : data.to_json
  end

  def cache_storage_url
    return nil if cache_storage_path.blank?

    # Return Object Storage URL if configured
    # Otherwise return local path
    if Rails.application.config.active_storage.service == :amazon
      # AWS S3 URL
      cache_storage_path
    else
      # Local storage path
      Rails.application.routes.url_helpers.rails_blob_path(cache_storage_path, only_path: true)
    end
  end

  def send_message(phone_number, message_content, attachments: [])
    # Send message via WhatsApp Web
    WhatsappWeb::NodeService.new(channel: self).send_message(phone_number, message_content, attachments)
  end

  private

  def generate_qr_code_token
    self.qr_code_token ||= SecureRandom.hex(32)
    self.qr_code_expires_at ||= 2.minutes.from_now
  end

  def initialize_whatsapp_client
    WhatsappWeb::ClientService.new(channel: self).initialize_client
  end

  def cleanup_storage
    # Stop Node.js client if running
    # Cleanup cache storage from Object Storage
    # Don't raise errors during cleanup to allow deletion to proceed (similar to other channels)
    begin
      # Stop client in Node.js service (non-blocking, don't fail if service is down)
      begin
        WhatsappWeb::ClientService.new(channel: self).stop_client
      rescue StandardError => e
        Rails.logger.debug { "[WHATSAPP_WEB] Stop client error (ignored): #{e.inspect}" }
        Rails.logger.debug { "[WHATSAPP_WEB] Stop client backtrace: #{e.backtrace.first(3).join("\n")}" } if Rails.env.development?
      end
      
      # Cleanup cache storage
      if cache_storage_path.present?
        begin
          WhatsappWeb::StorageService.new(channel: self).cleanup_cache
        rescue StandardError => e
          Rails.logger.debug { "[WHATSAPP_WEB] Cleanup cache error (ignored): #{e.inspect}" }
          Rails.logger.debug { "[WHATSAPP_WEB] Cleanup cache backtrace: #{e.backtrace.first(3).join("\n")}" } if Rails.env.development?
        end
      end
    rescue StandardError => e
      Rails.logger.debug { "[WHATSAPP_WEB] Cleanup storage error (ignored): #{e.inspect}" }
      Rails.logger.debug { "[WHATSAPP_WEB] Cleanup storage backtrace: #{e.backtrace.first(3).join("\n")}" } if Rails.env.development?
      # Don't re-raise - allow deletion to proceed (same pattern as Instagram/Facebook channels)
    end
    true # Always return true to allow deletion to proceed
  end
end

