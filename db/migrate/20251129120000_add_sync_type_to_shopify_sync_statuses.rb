class AddSyncTypeToShopifySyncStatuses < ActiveRecord::Migration[7.0]
  def change
    add_column :shopify_sync_statuses, :sync_type, :integer, default: 0, null: false
    # 0 = full (ilk sync), 1 = incremental (güncellemeler)
  end
end

