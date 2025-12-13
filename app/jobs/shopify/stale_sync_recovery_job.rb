# frozen_string_literal: true

# Takılmış (stale) sync işlemlerini tespit edip yeniden başlatan job
# Sidekiq restart, network timeout vb. durumlardan sonra sync'lerin kurtarılmasını sağlar
class Shopify::StaleSyncRecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  # 10 dakikadan fazla güncellenmemiş syncing durumundaki sync'leri stale kabul et
  STALE_THRESHOLD = 10.minutes

  def perform
    Rails.logger.info '[STALE SYNC RECOVERY] Starting stale sync check...'

    stale_syncs = find_stale_syncs
    
    if stale_syncs.empty?
      Rails.logger.info '[STALE SYNC RECOVERY] No stale syncs found'
      return
    end

    Rails.logger.warn "[STALE SYNC RECOVERY] Found #{stale_syncs.count} stale sync(s)"

    stale_syncs.find_each do |sync_status|
      recover_stale_sync(sync_status)
    end

    Rails.logger.info '[STALE SYNC RECOVERY] Stale sync recovery completed'
  end

  private

  def find_stale_syncs
    Shopify::SyncStatus.where(status: 'syncing')
                       .where('updated_at < ?', STALE_THRESHOLD.ago)
  end

  def recover_stale_sync(sync_status)
    hook = Integrations::Hook.find_by(id: sync_status.hook_id)

    unless hook&.enabled?
      Rails.logger.warn "[STALE SYNC RECOVERY] Hook #{sync_status.hook_id} not found or disabled, marking sync as failed"
      sync_status.update!(status: 'failed', error_message: 'Hook not found or disabled')
      return
    end

    Rails.logger.info "[STALE SYNC RECOVERY] Recovering stale sync for account #{sync_status.account_id}"

    # Mevcut sync'i failed olarak işaretle
    sync_status.update!(
      status: 'failed',
      error_message: "Sync stale (no update for #{STALE_THRESHOLD.inspect}) - auto restarted at #{Time.current}"
    )

    # Yeni sync başlat
    new_sync_status = Shopify::SyncStatus.create!(
      account_id: sync_status.account_id,
      hook_id: hook.id,
      status: 'syncing'
    )

    Shopify::SyncProductsBatchJob.perform_later(
      account_id: sync_status.account_id,
      hook_id: hook.id,
      sync_status_id: new_sync_status.id,
      page_info: nil,
      batch_size: 250,
      updated_since: nil
    )

    Rails.logger.info "[STALE SYNC RECOVERY] New sync started for account #{sync_status.account_id} (sync_status_id: #{new_sync_status.id})"
  rescue StandardError => e
    Rails.logger.error "[STALE SYNC RECOVERY] Error recovering sync for account #{sync_status.account_id}: #{e.message}"
  end
end

