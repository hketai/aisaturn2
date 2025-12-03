# == Schema Information
#
# Table name: shopify_sync_statuses
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  error_message   :text
#  failed_at       :datetime
#  started_at      :datetime
#  status          :integer          default("pending"), not null
#  synced_products :integer          default(0)
#  total_products  :integer          default(0)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  hook_id         :bigint           not null
#
# Indexes
#
#  index_shopify_sync_statuses_on_account_and_hook  (account_id,hook_id)
#  index_shopify_sync_statuses_on_created_at        (created_at)
#  index_shopify_sync_statuses_on_status            (status)
#
module Shopify
  class SyncStatus < Shopify::ApplicationRecord
    self.table_name = 'shopify_sync_statuses'
    
    belongs_to :account, class_name: '::Account'
    belongs_to :hook, class_name: '::Integrations::Hook'
    
    enum status: { 
      pending: 0,      # Sync başlatıldı, bekliyor
      syncing: 1,      # Sync devam ediyor
      completed: 2,    # Sync tamamlandı
      failed: 3,       # Sync başarısız
      cancelled: 4     # Sync iptal edildi
    }
    
    enum sync_type: {
      full: 0,         # İlk sync - tüm ürünler
      incremental: 1   # Artımlı sync - sadece güncellenenler
    }
    
    validates :account_id, presence: true
    validates :hook_id, presence: true
    
    scope :active, -> { where(status: [:pending, :syncing]) }
    scope :recent, -> { order(created_at: :desc) }
    
    def progress_percentage
      return 0 if total_products.zero?
      ((synced_products.to_f / total_products) * 100).round(2)
    end
    
    def update_progress(synced:, total:)
      update!(
        synced_products: synced,
        total_products: total,
        status: synced >= total ? :completed : :syncing
      )
    end
    
    def mark_completed
      update!(
        status: :completed,
        completed_at: Time.current,
        error_message: nil
      )
    end
    
    def mark_failed(error)
      update!(
        status: :failed,
        failed_at: Time.current,
        error_message: error.message
      )
    end
  end
end

