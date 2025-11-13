# Hybrid Storage Service for WhatsApp Web
# - Auth Data (1 MB): Stored encrypted in PostgreSQL
# - Cache Data (200+ MB): Stored compressed in Object Storage
require 'zlib'
require 'stringio'

class WhatsappWeb::StorageService
  pattr_initialize [:channel!]

  def save_auth_data(auth_data)
    # Save auth data (small, ~1 MB) encrypted in PostgreSQL
    channel.update!(auth_data_encrypted: auth_data.to_json)
  end

  def load_auth_data
    return nil if channel.auth_data_encrypted.blank?

    JSON.parse(channel.auth_data_encrypted)
  rescue JSON::ParserError
    nil
  end

  def save_cache_data(cache_data)
    # Save cache data (large, 200+ MB) compressed in Object Storage
    compressed_data = compress_cache(cache_data)
    
    # Upload to Object Storage (S3 or local)
    storage_path = upload_to_storage(compressed_data)
    
    channel.update!(cache_storage_path: storage_path)
    storage_path
  end

  def load_cache_data
    return nil if channel.cache_storage_path.blank?

    # Download from Object Storage
    compressed_data = download_from_storage(channel.cache_storage_path)
    return nil if compressed_data.blank?

    # Decompress
    decompress_cache(compressed_data)
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Cache load error: #{e.message}"
    nil
  end

  def cleanup_cache
    return if channel.cache_storage_path.blank?

    begin
      storage_path = channel.cache_storage_path
      delete_from_storage(storage_path)
      # Only update if channel still exists and is not being destroyed
      # Use update_column to avoid validations/callbacks during cleanup
      if channel.persisted? && !channel.destroyed?
        begin
          channel.update_column(:cache_storage_path, nil)
        rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid => e
          # Channel might be destroyed concurrently, ignore
          Rails.logger.debug "[WHATSAPP_WEB] Cache path update skipped: #{e.class.name}"
        end
      end
    rescue StandardError => e
      Rails.logger.error "[WHATSAPP_WEB] Cleanup cache error: #{e.message}"
      Rails.logger.error "[WHATSAPP_WEB] Cleanup cache backtrace: #{e.backtrace.first(5).join("\n")}" if Rails.env.development?
      # Don't re-raise - allow cleanup to continue
    end
  end

  private

  def compress_cache(data)
    # Compress cache data using Zlib
    Zlib::Deflate.deflate(data.to_json)
  end

  def decompress_cache(compressed_data)
    # Decompress cache data
    json_data = Zlib::Inflate.inflate(compressed_data)
    JSON.parse(json_data)
  end

  def upload_to_storage(data)
    # Upload to Active Storage (S3 or local)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(data),
      filename: "whatsapp_web_cache_#{channel.id}_#{Time.current.to_i}.gz",
      content_type: 'application/gzip'
    )

    blob.key
  end

  def download_from_storage(storage_path)
    blob = ActiveStorage::Blob.find_by(key: storage_path)
    return nil unless blob

    blob.download
  end

  def delete_from_storage(storage_path)
    return if storage_path.blank?

    begin
      blob = ActiveStorage::Blob.find_by(key: storage_path)
      blob&.purge
    rescue ActiveRecord::RecordNotFound, StandardError => e
      # Blob might already be deleted or not found, ignore
      Rails.logger.debug "[WHATSAPP_WEB] Delete blob error (ignored): #{e.class.name}"
    end
  end
end

